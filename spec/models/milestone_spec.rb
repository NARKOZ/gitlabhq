# == Schema Information
#
# Table name: milestones
#
#  id          :integer          not null, primary key
#  title       :string(255)      not null
#  project_id  :integer          not null
#  description :text
#  due_date    :date
#  created_at  :datetime
#  updated_at  :datetime
#  state       :string(255)
#  iid         :integer
#

require 'spec_helper'

describe Milestone do
  describe "Associations" do
    it { should belong_to(:project) }
    it { should have_many(:issues) }
  end

  describe "Mass assignment" do
    it { should_not allow_mass_assignment_of(:project_id) }
  end

  describe "Validation" do
    before { subject.stub(set_iid: false) }
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:project) }
  end

  let(:milestone) { create(:milestone) }
  let(:issue) { create(:issue) }

  describe "#percent_complete" do
    it "should not count open issues" do
      milestone.issues << issue
      expect(milestone.percent_complete).to eq(0)
    end

    it "should count closed issues" do
      issue.close
      milestone.issues << issue
      expect(milestone.percent_complete).to eq(100)
    end

    it "should recover from dividing by zero" do
      expect(milestone.issues).to receive(:count).and_return(0)
      expect(milestone.percent_complete).to eq(100)
    end
  end

  describe "#expires_at" do
    it "should be nil when due_date is unset" do
      milestone.update_attributes(due_date: nil)
      expect(milestone.expires_at).to be_nil
    end

    it "should not be nil when due_date is set" do
      milestone.update_attributes(due_date: Date.tomorrow)
      expect(milestone.expires_at).to be_present
    end
  end

  describe :expired? do
    context "expired" do
      before do
        milestone.stub(due_date: Date.today.prev_year)
      end

      it { expect(milestone.expired?).to be_true }
    end

    context "not expired" do
      before do
        milestone.stub(due_date: Date.today.next_year)
      end

      it { expect(milestone.expired?).to be_false }
    end
  end

  describe :percent_complete do
    before do
      milestone.stub(
        closed_items_count: 3,
        total_items_count: 4
      )
    end

    it { expect(milestone.percent_complete).to eq(75) }
  end

  describe :items_count do
    before do
      milestone.issues << create(:issue)
      milestone.issues << create(:closed_issue)
      milestone.merge_requests << create(:merge_request)
    end

    it { expect(milestone.closed_items_count).to eq(1) }
    it { expect(milestone.open_items_count).to eq(2) }
    it { expect(milestone.total_items_count).to eq(3) }
    it { expect(milestone.is_empty?).to be_false }
  end

  describe :can_be_closed? do
    it { expect(milestone.can_be_closed?).to be_true }
  end

  describe :is_empty? do
    before do
      issue = create :closed_issue, milestone: milestone
      merge_request = create :merge_request, milestone: milestone
    end

    it 'Should return total count of issues and merge requests assigned to milestone' do
      expect(milestone.total_items_count).to eq 2
    end
  end

  describe :can_be_closed? do
    before do
      milestone = create :milestone
      create :closed_issue, milestone: milestone

      issue = create :issue
    end

    it 'should be true if milestone active and all nested issues closed' do
      expect(milestone.can_be_closed?).to be_true
    end

    it 'should be false if milestone active and not all nested issues closed' do
      issue.milestone = milestone
      issue.save

      expect(milestone.can_be_closed?).to be_false
    end
  end

end
