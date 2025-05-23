
#
# NeuroHub Project
#
# Copyright (C) 2020
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# Session management for NeuroHub
class NhSessionsController < NeurohubApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include OrcidHelpers

  before_action :login_required,    :except => [ :new, :create, :request_password, :send_password, :orcid, :nh_oidc ]
  before_action :already_logged_in, :except => [ :orcid, :destroy, :nh_oidc, :nh_unlink_oidc, :nh_mandatory_oidc ]

  def new #:nodoc:
    @orcid_uri      = orcid_login_uri()
    # Array of enabled OIDC providers configurations
    @oidc_configs   = OidcConfig.all
    # Hash of OIDC uris with the OIDC name as key
    @oidc_uris      = generate_oidc_login_uri(@oidc_configs, "nh_route_please")
  end

  # POST /nhsessions
  # Users log in with username and password
  def create #:nodoc:
    username = params[:username] # in CBRAIN we use 'login'
    password = params[:password]

    # Ugly cross-controller invocation... :-(
    # FIXME
    all_ok, new_cb_session = eval_in_controller(::SessionsController) do
      user = User.authenticate(username,password) # can be nil if it fails
      ok   = create_from_user(user, 'NeuroHub')
      [ok, cbrain_session]
    end
    @cbrain_session = new_cb_session # crush the session object that was created for the NhSessionsController

    if ! all_ok
      flash[:error] = 'Invalid username or password.'
      redirect_to signin_path
      return
    end

    # Record that the user connected using the NeuroHub login page
    cbrain_session[:login_page] = 'NeuroHub'

    redirect_to neurohub_path
  end

  # GET /signout
  def destroy
    reset_session
    redirect_to signin_path
  end

  def request_password #:nodoc:
  end

  def send_password #:nodoc:
  end

  # POST /orcid
  # Users log in with ORCID authentication, or if already
  # logged in, links their account to their ORCID account
  def orcid #:nodoc:
    code = params[:code].presence
    if code.blank?
      redirect_to signin_path
      return
    end

    myself              = RemoteResource.current_resource
    site_uri            = myself.site_url_prefix.presence.try(:strip)
    orcid_client_id     = myself.meta[:orcid_client_id].presence.try(:strip)
    orcid_client_secret = myself.meta[:orcid_client_secret].presence.try(:strip)

    if site_uri.blank? || orcid_client_id.blank? || orcid_client_secret.blank?
      flash[:error] = 'ORCID authentication not configured on this service.'
      redirect_to signin_path
      return
    end

    # Query ORCID, get a JSON record with an ORCID iD.
    response = Typhoeus.post(ORCID_TOKEN_URI,
      :body   => {
                   :code          => code,
                   :client_id     => orcid_client_id,
                   :client_secret => orcid_client_secret,
                   :grant_type    => 'authorization_code',
                   :redirect_uri  => orcid_url, # is this needed?
                 },
      :headers => { :Accept       => 'application/json' }
    )

    # Extract the ORCID iD of the user
    body  = response.response_body
    json  = JSON.parse(body)
    orcid = json['orcid'].presence
    Rails.logger.info "ORCID reply: #{json.to_h.hide_filtered.inspect}"

    if orcid.blank?
      redirect_to neurohub_path
      return
    end

    if current_user.blank?
      login_with_orcid(orcid)
    else
      record_user_orcid(orcid)
    end

  rescue => ex
    clean_bt = Rails.backtrace_cleaner.clean(ex.backtrace || [])
    Rails.logger.info "ORCID auth failed: #{ex.class} #{ex.message} at #{clean_bt[0]}"
    flash[:error] = 'The ORCID authentication failed'
    redirect_to signin_path
  end

  # This action receives a JSON authentication
  # request from an OpenID provider and uses it to record or verify
  # a user's identity.
  def nh_oidc
    code  = params[:code].presence.try(:strip)
    state = params[:state].presence

    # Some initial simple validations
    oidc = OidcConfig.find_by_state(state) if state
    if !code || !oidc || state != oidc_current_state(oidc)
      cb_error "#{oidc&.name || 'OIDC'} session is out of sync with CBRAIN"
    end

    # Query an OpenID provider; this returns all the info we need at the same time.
    identity_struct = oidc_fetch_token(oidc, code, oidc_redirect_url(oidc, "nh_route_please"))
    if !identity_struct
      cb_error "Could not fetch your identity information from #{oidc.name}"
    end
    Rails.logger.info "#{oidc.name} identity struct:\n#{identity_struct.pretty_inspect.strip}"
    identity_provider_id, identity_provider_name, username = oidc.identity_info(identity_struct)
    cb_error "Identity structure is missing some information. Contact the admins" if
      identity_provider_id.blank? || identity_provider_name.blank? || username.blank?

    # Either record the identity...
    if current_user
      if ! user_can_link_to_oidc_identity?(oidc, current_user, identity_struct)
        Rails.logger.error("User #{current_user.login} attempted authentication " +
                           "with unallowed identity provider" + identity_provider_name
                          )
        flash[:error] = "Error: your account can only authenticate with the following providers: " +
                        "#{allowed_oidc_provider_names(current_user).join(", ")}"
        redirect_to myaccount_path
        return
      end
      record_oidc_identity(oidc, current_user, identity_struct)
      flash[:notice] = "Your NeuroHub account is now linked to your #{oidc.name} identity."
      if user_must_link_to_oidc?(current_user)
        wipe_user_password_after_oidc_link(oidc, current_user)
        flash[:notice] += "\nImportant note: from now on you can no longer connect to NeuroHub using a password."
        redirect_to neurohub_path
        return
      end
      redirect_to myaccount_path
      return
    end

    # ...or attempt login with it
    user = find_user_with_oidc_identity(oidc, identity_struct)
    if user.is_a?(String) # an error occurred
      flash[:error] = user # the message
      redirect_to signin_path
      return
    end

    login_from_oidc_user(user, "#{oidc.name}/#{identity_provider_name}")

  rescue CbrainException => ex
    flash[:error] = "#{ex.message}"
    redirect_to signin_path
  rescue => ex
    clean_bt = Rails.backtrace_cleaner.clean(ex.backtrace || [])
    Rails.logger.error "#{oidc&.name || 'OIDC'} auth failed: #{ex.class} #{ex.message} at #{clean_bt[0]}"
    flash[:error] = "The #{oidc&.name || 'OIDC'} authentication failed"
    redirect_to signin_path
  end

  # POST /nh_unlink_oidc
  # Removes a user's linked OIDC identity.
  def nh_unlink_oidc #:nodoc:
    redirect_to start_page_path unless current_user

    oidc_name = params[:oidc_name]
    oidc      = OidcConfig.find_by_name(oidc_name)
    unlink_oidc_identity(oidc, current_user) if oidc

    flash[:notice] = "Your account is no longer linked to any #{oidc.name} identity"
    redirect_to myaccount_path
  end

  # GET /nh_mandatory_oidc
  # Shows the page that informs the user they MUST link to a provider ID.
  def nh_mandatory_oidc #:nodoc:
    # Restrict @allowed_oidc_providers to allowed providers
    @allowed_prov_names = allowed_oidc_provider_names(current_user)
    # Array of enabled OIDC providers configurations
    @oidc_configs       = OidcConfig.all
    # Hash of OIDC uris with the OIDC name as key
    @oidc_uris          = generate_oidc_login_uri(@oidc_configs, "nh_route_please")

    respond_to do |format|
      format.html
      format.any  { head :unauthorized }
    end
  end

  private

  def record_user_orcid(orcid) #:nodoc:
    current_orcid = current_user.meta[:orcid].presence.try(:strip)

    if current_orcid == orcid
      flash[:notice] = "Your ORCID ID is unchanged."
      redirect_to myaccount_path
      return
    end

    if current_orcid.blank?
      flash[:notice] = "Your ORCID ID has been recorded."
    else
      flash[:notice] = "Your ORCID ID has been updated."
    end

    current_user.meta[:orcid] = orcid # auto-saves
    current_user.touch
    current_user.addlog("Set ORCID to #{orcid}")
    redirect_to myaccount_path
  end

  def login_with_orcid(orcid)
    # Find the users that have it. Hopefully, only one.
    users = User.find_all_by_meta_data(:orcid, orcid)

    if users.size == 0
      flash[:error] = "No NeuroHub user matches your ORCID iD. Create a NeuroHub account, or add your ORCID ID to your NeuroHub account."
      redirect_to signin_path
      return
    elsif users.size > 1
      flash[:notice] = "Several NeuroHub user accounts matches your ORCID iD. Using the most recently updated one."
      users = [ users.sort_by(&:updated_at).last ]
    end
    user = users.first

    # Login by hijacking CBRAIN's system
    all_ok, new_cb_session = eval_in_controller(::SessionsController) do
      ok  = create_from_user(user, 'NeuroHub/ORCID')
      [ok, cbrain_session]
    end
    @cbrain_session = new_cb_session # crush the session object that was created for the NhSessionsController

    if ! all_ok
      redirect_to signin_path
      return
    end

    # All's good
    redirect_to neurohub_path
  end

  def login_from_oidc_user(user, provider_name)
    # Login the user
    all_ok, new_cb_session = eval_in_controller(::SessionsController) do
      ok  = create_from_user(user, "NeuroHub/#{provider_name}")
      [ok, cbrain_session]
    end
    @cbrain_session = new_cb_session # crush the session object that was created for the NhSessionsController

    if ! all_ok
      redirect_to signin_path
      return
    end

    # Record that the user connected using the CBRAIN login page
    cbrain_session[:login_page] = 'NeuroHub'

    # All's good
    redirect_to neurohub_path
  end

  # before_action callback
  def already_logged_in
    if current_user
      respond_to do |format|
        flash[:notice] = 'You are already logged in.'
        format.html { redirect_to neurohub_path }
      end
    end
  end

end
