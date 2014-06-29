# == Schema Information
#
# Table name: issues
#
#  id           :integer          not null, primary key
#  title        :string(255)
#  assignee_id  :integer
#  author_id    :integer
#  project_id   :integer
#  created_at   :datetime
#  updated_at   :datetime
#  position     :integer          default(0)
#  branch_name  :string(255)
#  description  :text
#  milestone_id :integer
#  state        :string(255)
#  iid          :integer
#

require 'spec_helper'

describe Issue do
  describe "Associations" do
    it { should belong_to(:milestone) }
  end

  describe "Mass assignment" do
    it { should_not allow_mass_assignment_of(:author_id) }
    it { should_not allow_mass_assignment_of(:project_id) }
  end

  describe 'modules' do
    it { should include_module(Issuable) }
  end

  subject { create(:issue) }

  describe '#is_being_reassigned?' do
    it 'returns true if the issue assignee has changed' do
      subject.assignee = create(:user)
      expect(subject.is_being_reassigned?).to be_true
    end
    it 'returns false if the issue assignee has not changed' do
      expect(subject.is_being_reassigned?).to be_false
    end
  end

  describe '#is_being_reassigned?' do
    it 'returns issues assigned to user' do
      user = create :user

      2.times do
        issue = create :issue, assignee: user
      end

      expect(Issue.open_for(user).count).to eq 2
    end
  end

  it_behaves_like 'an editable mentionable' do
    let(:subject) { create :issue, project: mproject }
    let(:backref_text) { "issue ##{subject.iid}" }
    let(:set_mentionable_text) { ->(txt){ subject.description = txt } }
  end
end
