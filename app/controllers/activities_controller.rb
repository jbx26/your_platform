class ActivitiesController < ApplicationController
  skip_authorization_check only: :index
  
  def index
    authorize! :index, PublicActivity::Activity
    
    @user = User.find params[:user_id] if params[:user_id].present?
    
    @activities = PublicActivity::Activity
    @activities = @activities.where("(owner_type='User' and owner_id=?) or (trackable_type='User' and trackable_id=?)", @user.id, @user.id) if @user
    @activities = @activities.where(owner: current_user.administrated_objects.select { |o| o.kind_of?(User) }) unless Role.of(current_user).global_admin?
    @activities = @activities.order('created_at desc').limit(100)
    
    set_current_title "#{t(:activity_log)}: #{@user.try(:title)}"
  end
end