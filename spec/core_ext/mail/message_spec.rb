require 'spec_helper'

describe Mail::Message do
  describe "#deliver" do
    subject { @message.deliver_now } # will call `deliver` internally

    describe "when using the delivery-filter feature" do
      before do
        require_relative '../../../app/models/ability'
        class Ability
          def rights_for_everyone
            can :use, :mail_delivery_account_filter # Feature Switch
          end
        end
      end

      describe "for users without account" do
        before do
          @user = create :user, email: 'john@example.com'
          @random_string = ('a'..'z').to_a.shuffle[0,8].join
          @message = UserAccountMailer.welcome_email(@user, "Test: #{@random_string}")
        end

        it { should == false }
        it "should not send a message" do
          last_email.to_s.should_not include @random_string
        end
      end
    end
  end
end