require 'spec_helper'

describe API::API, api: true  do
  include ApiHelpers

  let(:user1) { create(:user) }
  let(:user2) { create(:user) }
  let(:admin) { create(:admin) }
  let!(:group1) { create(:group) }
  let!(:group2) { create(:group) }

  before do
    group1.add_owner(user1)
    group2.add_owner(user2)
  end

  describe "GET /groups" do
    context "when unauthenticated" do
      it "should return authentication error" do
        get api("/groups")
        expect(response.status).to eq(401)
      end
    end

    context "when authenticated as user" do
      it "normal user: should return an array of groups of user1" do
        get api("/groups", user1)
        expect(response.status).to eq(200)
        expect(json_response).to be_an Array
        expect(json_response.length).to eq(1)
        expect(json_response.first['name']).to eq(group1.name)
      end
    end

    context "when authenticated as  admin" do
      it "admin: should return an array of all groups" do
        get api("/groups", admin)
        expect(response.status).to eq(200)
        expect(json_response).to be_an Array
        expect(json_response.length).to eq(2)
      end
    end
  end

  describe "GET /groups/:id" do
    context "when authenticated as user" do
      it "should return one of user1's groups" do
        get api("/groups/#{group1.id}", user1)
        expect(response.status).to eq(200)
        json_response['name'] == group1.name
      end

      it "should not return a non existing group" do
        get api("/groups/1328", user1)
        expect(response.status).to eq(404)
      end

      it "should not return a group not attached to user1" do
        get api("/groups/#{group2.id}", user1)
        expect(response.status).to eq(403)
      end
    end

    context "when authenticated as admin" do
      it "should return any existing group" do
        get api("/groups/#{group2.id}", admin)
        expect(response.status).to eq(200)
        json_response['name'] == group2.name
      end

      it "should not return a non existing group" do
        get api("/groups/1328", admin)
        expect(response.status).to eq(404)
      end
    end
  end

  describe "POST /groups" do
    context "when authenticated as user" do
      it "should not create group" do
        post api("/groups", user1), attributes_for(:group)
        expect(response.status).to eq(403)
      end
    end

    context "when authenticated as admin" do
      it "should create group" do
        post api("/groups", admin), attributes_for(:group)
        expect(response.status).to eq(201)
      end

      it "should not create group, duplicate" do
        post api("/groups", admin), {name: "Duplicate Test", path: group2.path}
        expect(response.status).to eq(404)
      end

      it "should return 400 bad request error if name not given" do
        post api("/groups", admin), {path: group2.path}
        expect(response.status).to eq(400)
      end

      it "should return 400 bad request error if path not given" do
        post api("/groups", admin), { name: 'test' }
        expect(response.status).to eq(400)
      end
    end
  end

  describe "DELETE /groups/:id" do
    context "when authenticated as user" do
      it "should remove group" do
        delete api("/groups/#{group1.id}", user1)
        expect(response.status).to eq(200)
      end

      it "should not remove a group if not an owner" do
        user3 = create(:user)
        group1.add_user(user3, Gitlab::Access::MASTER)
        delete api("/groups/#{group1.id}", user3)
        expect(response.status).to eq(403)
      end

      it "should not remove a non existing group" do
        delete api("/groups/1328", user1)
        expect(response.status).to eq(404)
      end

      it "should not remove a group not attached to user1" do
        delete api("/groups/#{group2.id}", user1)
        expect(response.status).to eq(403)
      end
    end

    context "when authenticated as admin" do
      it "should remove any existing group" do
        delete api("/groups/#{group2.id}", admin)
        expect(response.status).to eq(200)
      end

      it "should not remove a non existing group" do
        delete api("/groups/1328", admin)
        expect(response.status).to eq(404)
      end
    end
  end

  describe "POST /groups/:id/projects/:project_id" do
    let(:project) { create(:project) }
    before(:each) do
      Projects::TransferService.any_instance.stub(execute: true)
      allow(Project).to receive(:find).and_return(project)
    end

    context "when authenticated as user" do
      it "should not transfer project to group" do
        post api("/groups/#{group1.id}/projects/#{project.id}", user2)
        expect(response.status).to eq(403)
      end
    end

    context "when authenticated as admin" do
      it "should transfer project to group" do
        post api("/groups/#{group1.id}/projects/#{project.id}", admin)
        expect(response.status).to eq(201)
      end
    end
  end

  describe "members" do
    let(:owner) { create(:user) }
    let(:reporter) { create(:user) }
    let(:developer) { create(:user) }
    let(:master) { create(:user) }
    let(:guest) { create(:user) }
    let!(:group_with_members) do
      group = create(:group)
      group.add_users([reporter.id], UsersGroup::REPORTER)
      group.add_users([developer.id], UsersGroup::DEVELOPER)
      group.add_users([master.id], UsersGroup::MASTER)
      group.add_users([guest.id], UsersGroup::GUEST)
      group
    end
    let!(:group_no_members) { create(:group) }

    before do
      group_with_members.add_owner owner
      group_no_members.add_owner owner
    end

    describe "GET /groups/:id/members" do
      context "when authenticated as user that is part or the group" do
        it "each user: should return an array of members groups of group3" do
          [owner, master, developer, reporter, guest].each do |user|
            get api("/groups/#{group_with_members.id}/members", user)
            expect(response.status).to eq(200)
            expect(json_response).to be_an Array
            expect(json_response.size).to eq(5)
            expect(json_response.find { |e| e['id']==owner.id }['access_level']).to eq(UsersGroup::OWNER)
            expect(json_response.find { |e| e['id']==reporter.id }['access_level']).to eq(UsersGroup::REPORTER)
            expect(json_response.find { |e| e['id']==developer.id }['access_level']).to eq(UsersGroup::DEVELOPER)
            expect(json_response.find { |e| e['id']==master.id }['access_level']).to eq(UsersGroup::MASTER)
            expect(json_response.find { |e| e['id']==guest.id }['access_level']).to eq(UsersGroup::GUEST)
          end
        end

        it "users not part of the group should get access error" do
          get api("/groups/#{group_with_members.id}/members", user1)
          expect(response.status).to eq(403)
        end
      end
    end

    describe "POST /groups/:id/members" do
      context "when not a member of the group" do
        it "should not add guest as member of group_no_members when adding being done by person outside the group" do
          post api("/groups/#{group_no_members.id}/members", reporter), user_id: guest.id, access_level: UsersGroup::MASTER
          expect(response.status).to eq(403)
        end
      end

      context "when a member of the group" do
        it "should return ok and add new member" do
          count_before=group_no_members.users_groups.count
          new_user = create(:user)
          post api("/groups/#{group_no_members.id}/members", owner), user_id: new_user.id, access_level: UsersGroup::MASTER
          expect(response.status).to eq(201)
          expect(json_response['name']).to eq(new_user.name)
          expect(json_response['access_level']).to eq(UsersGroup::MASTER)
          expect(group_no_members.users_groups.count).to eq(count_before + 1)
        end

        it "should return error if member already exists" do
          post api("/groups/#{group_with_members.id}/members", owner), user_id: master.id, access_level: UsersGroup::MASTER
          expect(response.status).to eq(409)
        end

        it "should return a 400 error when user id is not given" do
          post api("/groups/#{group_no_members.id}/members", owner), access_level: UsersGroup::MASTER
          expect(response.status).to eq(400)
        end

        it "should return a 400 error when access level is not given" do
          post api("/groups/#{group_no_members.id}/members", owner), user_id: master.id
          expect(response.status).to eq(400)
        end

        it "should return a 422 error when access level is not known" do
          post api("/groups/#{group_no_members.id}/members", owner), user_id: master.id, access_level: 1234
          expect(response.status).to eq(422)
        end
      end
    end

    describe "DELETE /groups/:id/members/:user_id" do
      context "when not a member of the group" do
        it "should not delete guest's membership of group_with_members" do
          random_user = create(:user)
          delete api("/groups/#{group_with_members.id}/members/#{owner.id}", random_user)
          expect(response.status).to eq(403)
        end
      end

      context "when a member of the group" do
        it "should delete guest's membership of group" do
          count_before=group_with_members.users_groups.count
          delete api("/groups/#{group_with_members.id}/members/#{guest.id}", owner)
          expect(response.status).to eq(200)
          expect(group_with_members.users_groups.count).to eq(count_before - 1)
        end

        it "should return a 404 error when user id is not known" do
          delete api("/groups/#{group_with_members.id}/members/1328", owner)
          expect(response.status).to eq(404)
        end
      end
    end
  end
end
