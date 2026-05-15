Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "dashboard#index"

  resource :registeration
  resource :session
  resource :password_reset
  resources :campaigns
  resources :user

  resources :candidates do
    collection do
      get "recent"
      get "hot"
      get "pipeline"
      get "champions"
      get "joinings"
      get "icebox"
      get "archive"
      get "incomplete"
      get "alumni"
      get "employees"
      get "contractors"
      get "leads"
      get "nurture"
      get "inbound"
      post "leads", to: "candidates#settle_leads"
      post "inbound", to: "candidates#settle_inbound"
    end

    scope module: "candidate" do
      resources :interviews
      resources :checklists
      resources :notes
      resources :emails
      resources :reviews
      resources :campaigns
      resources :resume
      get "timeline", to: "timeline#index"
      patch "/update/bucket", to: "candidate#update_bucket", as: "update_bucket"
      patch "/update/status", to: "candidate#update_status", as: "update_status"
      patch "/update/campaign", to: "candidate#update_campaign", as: "update_campaign"
      patch "/update/owner", to: "candidate#update_owner", as: "update_owner"
      patch "/update/joining", to: "candidate#update_joining", as: "update_joining"
      patch "/update/recycle", to: "candidate#update_recycle", as: "update_recycle"
      patch "/toggle/recycle", to: "candidate#toggle_recycle", as: "toggle_recycle"
      patch "/reject_and_icebox", to: "candidate#reject_and_icebox", as: "reject_and_icebox"
      patch "/reject_and_archive", to: "candidate#reject_and_archive", as: "reject_and_archive"

      patch "/reward_to_recruiter/:recruiter_id", to: "candidate#reward_to_recruiter", as: "reward_to_recruiter"
      get "/edit/joining", to: "candidate#edit_joining", as: "edit_joining"
      get "/edit/recycle", to: "candidate#edit_recycle", as: "edit_recycle"
    end
  end

  resources :members do
    scope module: "member" do
      resources :interviews
      resources :reviews
      resources :feedbacks
      resources :candidates
      resources :reports
      get "timeline", to: "timeline#index"
    end
  end

  resources :openings do
    member do
      post :toggle_interviewer
    end
    collection do
      get "description"
    end

    scope module: "opening" do
      resources :interviews, only: [:index]
      resources :associations
      resources :champions
      resources :note
      resources :description
      resources :ai_scores, only: [:index, :show, :create]
      get "timeline", to: "timeline#index"
    end
  end

  namespace :account do
    resources :roles, except: [:new, :show]
    resources :sources, except: [:new, :show]
  end

  scope "/settings" do
    get "/profile", to: "user#profile", as: "profile"
    get "/password", to: "user#password", as: "setting_password"
    get "/import", to: "user#import", as: "import"
    post "/import_csv", to: "user#import_csv", as: "import_csv"
    patch "/password", to: "user#update_password", as: "edit_password"
    get "/preferences", to: "user#preferences", as: "user_preferences"
    patch "/avatar", to: "user#update_avatar", as: "avatar"
    delete "/avatar", to: "user#destroy_avatar", as: "destroy_avatar"
  end

  scope "/search" do
    get "/candidates", to: "search#candidates"
  end

  resources :interviews
  resources :reports
  resources :buckets
  resources :pipeline
  resources :checklists
  resources :campaigns
  post "/campaigns/:id/close", to: "campaigns#close", as: "close_campaign"

  get :events, controller: :dashboard
  get :recycles, controller: :dashboard
  get :recycle, controller: :recycles, action: :index
  post :recycle, controller: :recycles, action: :settle

  scope "report" do
    get "/candidates", to: "report/candidates#index", as: "report_candidates"
    get "/new_candidates", to: "report/new_candidates#index", as: "report_new_candidates"
    get "/update_candidates", to: "report/update_candidates#index", as: "report_update_candidates"
    get "/bucket_report", to: "report/bucket_report#index", as: "bucket_report"
  end

  scope "/public" do
    get "/thanks", to: "public/apply#thanks", as: "public_thanks"
    get "/team", to: "public/team#index", as: "public_team"
    get "/openings", to: "public/openings#index", as: "public_openings"
    get "/openings/apply", to: "public/apply#index", as: "public_apply"
    post "/openings/apply", to: "public/apply#create", as: "public_apply_create"
    get "/openings/:id", to: "public/openings#show", as: "show_public_openings"
  end
end
