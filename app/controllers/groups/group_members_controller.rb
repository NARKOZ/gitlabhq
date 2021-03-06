class Groups::GroupMembersController < Groups::ApplicationController
  skip_before_filter :authenticate_user!, only: [:index]
  before_filter :group

  # Authorize
  before_filter :authorize_read_group!
  before_filter :authorize_admin_group!, except: [:index, :leave]

  layout :determine_layout

  def index
    @project = @group.projects.find(params[:project_id]) if params[:project_id]
    @members = @group.group_members

    if params[:search].present?
      users = @group.users.search(params[:search]).to_a
      @members = @members.where(user_id: users)
    end

    @members = @members.order('access_level DESC').page(params[:page]).per(50)
    @group_member = GroupMember.new
  end

  def create
    @group.add_users(params[:user_ids].split(','), params[:access_level])

    redirect_to group_group_members_path(@group), notice: 'Users were successfully added.'
  end

  def update
    @member = @group.group_members.find(params[:id])
    @member.update_attributes(member_params)
  end

  def destroy
    @group_member = @group.group_members.find(params[:id])

    if can?(current_user, :destroy_group_member, @group_member)  # May fail if last owner.
      @group_member.destroy
      respond_to do |format|
        format.html { redirect_to group_group_members_path(@group), notice: 'User was  successfully removed from group.' }
        format.js { render nothing: true }
      end
    else
      return render_403
    end
  end

  def leave
    @group_member = @group.group_members.where(user_id: current_user.id).first
    
    if can?(current_user, :destroy_group_member, @group_member)
      @group_member.destroy
      redirect_to(dashboard_groups_path, info: "You left #{group.name} group.")
    else
      return render_403
    end
  end

  protected

  def group
    @group ||= Group.find_by(path: params[:group_id])
  end

  def member_params
    params.require(:group_member).permit(:access_level, :user_id)
  end
end
