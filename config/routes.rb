# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users

  # Home
  root "home#index"
  get "about", to: "home#about"
  get "help", to: "home#help"
  get "accessibility", to: "home#accessibility"
  get "home/forms_picker", to: "home#forms_picker", as: :forms_picker_home

  # Admin namespace
  namespace :admin do
    root "dashboard#index"
    resources :feedbacks, only: [ :index, :show, :update ] do
      member do
        patch :acknowledge
        patch :resolve
      end
    end
    resources :analytics, only: [ :index ]
  end

  # Form Feedbacks (public submission)
  resources :form_feedbacks, only: [ :create ]

  # Profile
  resource :profile, only: [ :show, :update ]

  # Forms (individual access)
  resources :forms, only: [ :index, :show, :update ], param: :id do
    member do
      get :preview
      get :download
      post :toggle_wizard
    end
  end

  # Workflows (guided wizard)
  resources :workflows, only: [ :index, :show ], param: :id do
    member do
      patch :step
      post :advance
      post :back
      get :complete
    end
  end

  # Submissions (user's saved forms)
  resources :submissions, only: [ :index, :show, :destroy ] do
    member do
      get :pdf
      get :download_pdf
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Test-only routes (development/test only)
  if Rails.env.development? || Rails.env.test?
    scope :test_only do
      get "create_submission", to: "test_only#create_submission"
      get "create_session_submission", to: "test_only#create_session_submission"
      post "reset", to: "test_only#reset"
    end
  end
end
