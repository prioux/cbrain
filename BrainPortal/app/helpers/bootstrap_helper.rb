
module BootstrapHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def bs_menubar(&block)
    '<div class="row menu_bar"><div class="col-xs-12"><div class="well well-sm">'.html_safe +
      capture(&block) +
    '</div></div></div>'.html_safe
  end

  def bs_ban_icon(text="")
    "<span class=\"glyphicon glyphicon-ban-circle\"></span> #{text}".html_safe
  end

  def bs_switch_icon(text="")
    "<span class=\"glyphicon glyphicon-random\"></span> #{text}".html_safe
  end

  def bs_trash_icon(text="")
    "<span class=\"glyphicon glyphicon-trash\"></span> #{text}".html_safe
  end

  def bs_error_messages_for(*args)
    '<div class="row"><div class="col-xs-12">'.html_safe +
      error_messages_for(*args) +
    '</div></div>'.html_safe
  end

  def bs_row(&block)
    '<div class="row">'.html_safe +
      capture(&block) +
    '</div>'.html_safe
  end

  def bs_show_table(*args,&block)
    '<div class="col-xs-12 col-md-6">'.html_safe +
      show_table(*args,&block) +
    '</div>'.html_safe
  end

end

