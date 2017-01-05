class ApplicationsController < ApplicationController
  before_action :redirect_if_read_only_user, only: [:new, :edit, :create, :update, :update_notes]
  before_action :find_application, only: [:show, :edit, :update, :update_notes, :deploy]

  def index
    @environments = %w(staging production)
    @applications = Application.where(archived: false)
  end

  def archived
    @environments = %w(staging production)
    @applications = Application.where(archived: true)
  end

  def show
    @tags_by_commit = github.tags(@application.repo).each_with_object({}) do |tag, hash|
      sha = tag[:commit][:sha];
      hash[sha] ||= [];
      hash[sha] << tag
    end
    # where version == git tag, which it isn't for licensify
    @latest_deploy_to_each_environment_by_version = {}
    @application.latest_deploy_to_each_environment.each do |_environment, deployment|
      @latest_deploy_to_each_environment_by_version[deployment.version] ||= []
      @latest_deploy_to_each_environment_by_version[deployment.version] << deployment
    end

    @production_deploy = @application.deployments.last_deploy_to "production"
    if @production_deploy
      comparison = github.compare(
        @application.repo,
        @production_deploy.version,
        "master"
      )
      # The `compare` API shows commits in forward chronological order
      @commits = comparison.commits.reverse + [comparison.base_commit]
    else
      # the `commits` API shows commits in reverse chronological order
      @commits = github.commits(@application.repo)
    end

    @github_available = true
    @latest_deployments = @application.deployments.newest_first.limit(25)
  rescue Octokit::NotFound => e
    @github_available = false
    @github_error = e
  rescue Octokit::Error => e
    Airbrake.notify(e)
    @github_available = false
    @github_error = e
  end

  def new
    @application = Application.new
  end

  def edit
  end

  def deploy
    @release_tag = params[:tag]

    @production_deploy = @application.deployments.last_deploy_to "production"
    if @production_deploy
      comparison = github.compare(
        @application.repo,
        @production_deploy.version,
        @release_tag
      )
      # The `compare` API shows commits in forward chronological order
      @commits = comparison.commits.reverse
    end
    @github_available = true
  rescue Octokit::NotFound => e
    @github_available = false
    @github_error = e
  end

  def create
    @application = Application.new(application_params)

    if @application.valid? && @application.save
      redirect_to @application, flash: { notice: "Successfully created new application" }
    else
      flash.now[:alert] = "There are some problems with the application"
      render action: "new"
    end
  end

  def update
    if @application.update_attributes(application_params)
      redirect_to @application, flash: { notice: "Successfully updated the application" }
    else
      flash.now[:alert] = "There are some problems with the application"
      render :edit
    end
  end

  def update_notes
    if @application.update_attributes(application_params)
      redirect_to applications_path, flash: { notice: "Successfully updated notes" }
    else
      redirect_to applications_path, flash: { alert: "Failed to update notes" }
    end
  end

private

  def find_application
    @application = Application.friendly.find(params[:id])
  end

  def github
    credentials = defined?(GITHUB_CREDENTIALS) ? GITHUB_CREDENTIALS : {}
    @client ||= Octokit::Client.new(credentials)
  end

  def application_params
    params.require(:application).permit(
      :archived,
      :domain,
      :id,
      :name,
      :repo,
      :shortname,
      :status_notes,
      :task,
    )
  end
end
