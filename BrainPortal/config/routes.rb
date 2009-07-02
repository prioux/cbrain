ActionController::Routing::Routes.draw do |map|
  map.resources :user_preferences



  map.resources :feedbacks

  map.resources :tags, :groups, :institutions, :users, :data_providers
  map.resources :data_providers, :member => { :browse => :get, :register => :post }
  map.resource :session
  map.resources :userfiles, :collection => {:operation => :post, :extract  => :post}, :member  => {:content  => :get}
  map.resources :single_files, :controller  => :userfiles
  map.resources :file_collection, :controller  => :userfiles
  map.resources :civet_collection, :controller  => :userfiles

  map.home    '/home', :controller => 'portal', :action => 'welcome'
  map.information '', :controller => 'portal', :action => 'credits'
  map.signup  '/signup', :controller => 'users', :action => 'new'
  map.login   '/login', :controller => 'sessions', :action => 'new'
  map.logout  '/logout', :controller => 'sessions', :action => 'destroy'
  map.jiv     '/jiv', :controller  => 'jiv', :action  => 'index'
  map.jiv_display '/jiv/show', :controller  => 'jiv', :action  => 'show'

  
  map.connect 'tasks/:action',                   :controller => 'tasks'
  map.connect 'tasks/:action/:cluster_name/:id', :controller => 'tasks'

  map.connect 'civet/:action/:id', :controller => 'civet'
  map.connect 'mnc2nii/:action/:id', :controller => 'mnc2nii'  
  
  map.connect 'cw5filter/:action/:id', :controller => 'cw5filter'
  map.connect 'cw5/:action/:id', :controller => 'cw5'  
  map.connect "logged_exceptions/:action/:id", :controller => "logged_exceptions" 

  # The priority is based upon order of creation: first created -> highest priority.

  # Sample of regular route:
  #   map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   map.resources :products

  # Sample resource route with options:
  #   map.resources :products, :member => { :short => :get, :toggle => :post }, :collection => { :sold => :get }

  # Sample resource route with sub-resources:
  #   map.resources :products, :has_many => [ :comments, :sales ], :has_one => :seller
  
  # Sample resource route with more complex sub-resources
  #   map.resources :products do |products|
  #     products.resources :comments
  #     products.resources :sales, :collection => { :recent => :get }
  #   end

  # Sample resource route within a namespace:
  #   map.namespace :admin do |admin|
  #     # Directs /admin/products/* to Admin::ProductsController (app/controllers/admin/products_controller.rb)
  #     admin.resources :products
  #   end

  # You can have the root of your site routed with map.root -- just remember to delete public/index.html.
  # map.root :controller => "welcome"

  # See how all your routes lay out with "rake routes"

  # Install the default routes as the lowest priority.
  # Note: These default routes make all actions in every controller accessible via GET requests. You should
  # consider removing the them or commenting them out if you're using named routes and resources.
  #map.connect ':controller/:action/:id'
  #map.connect ':controller/:action/:id.:format'
end
