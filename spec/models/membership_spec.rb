require 'spec_helper'

describe Membership do
  
  # Example: 
  #
  #      group1 --- page1 --- group2 --- group3 --- user1
  #        |
  #        |------- user2
  #
  before do
    @group1 = create :group, name: 'group1'
    @page1 = @group1.child_pages.create title: 'page1'
    @group2 = @page1.child_groups.create name: 'group2'
    @group3 = @group2.child_groups.create name: 'group3'
    @user1 = create :user; @group3 << @user1
    @user2 = create :user; @group1 << @user2
  end
  
  describe ".where(user: @user1)" do
    subject { Membership.where(user: @user1) }
    it { should be_kind_of MembershipCollection }
    its(:to_a) { should be_kind_of Array }
    its(:first) { should be_kind_of Membership }
    its(:count) { should == 2 }
  end
  
  describe ".where(group: @group3)" do
    subject { Membership.where(group: @group3) }
    it { should be_kind_of MembershipCollection }
    its(:to_a) { should be_kind_of Array }
    its(:first) { should be_kind_of Membership }
    its(:count) { should == 1 }
  end
  
  describe ".direct" do
    it "reduces the scope to direct memberships" do
      Membership.where(user: @user1).direct.count.should == 1
    end
    
    it "should be interchangable" do
      Membership.where(user: @user1).direct.to_a.should == Membership.direct.where(user: @user1).to_a
    end
  end

end