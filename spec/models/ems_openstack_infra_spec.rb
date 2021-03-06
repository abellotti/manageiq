require "spec_helper"

describe EmsOpenstackInfra do
  it ".ems_type" do
    described_class.ems_type.should == 'openstack_infra'
  end

  it ".description" do
    described_class.description.should == 'OpenStack Infrastructure'
  end

  context "validation" do
    before :each do
      @ems = FactoryGirl.create(:ems_openstack_infra_with_authentication)
      require 'openstack/openstack_event_monitor'
    end

    it "verifies AMQP credentials" do
      _, qconnection = EvmSpecHelper.stub_qpid_natives
      qconnection.should_receive(:open).and_return(nil)
      qconnection.should_receive(:open?).at_least(:twice).and_return(true)
      qconnection.should_receive(:close).and_return(nil)

      creds = {}
      creds[:amqp] = {:userid => "amqp_user", :password => "amqp_password"}
      @ems.update_authentication(creds, { :save => false })
      @ems.verify_credentials(:amqp).should be_true
    end

    it "indicates that an event monitor is available" do
      OpenstackEventMonitor.stub(:available?).and_return(true)
      @ems.event_monitor_available?.should be_true
    end

    it "indicates that an event monitor is not available" do
      OpenstackEventMonitor.stub(:available?).and_return(false)
      @ems.event_monitor_available?.should be_false
    end

    it "logs an error and indicates that an event monitor is not available when there's an error checking for an event monitor" do
      OpenstackEventMonitor.stub(:available?).and_raise(StandardError)
      $log.should_receive(:error).with(/Exeption trying to find openstack event monitor/)
      @ems.event_monitor_available?.should be_false
    end
  end

  context "provider_hooks" do
    before :each do
      @ems = FactoryGirl.create(:ems_openstack_infra_with_authentication)
    end

    it "creates related ProviderOpenstack after creating EmsOpenstackInfra" do
      @ems.provider.name.should eq @ems.name
      @ems.provider.zone.should == @ems.zone
      ProviderOpenstack.count.should eq 1
    end

    it "destroys related ProviderOpenstack after destroying EmsOpenstackInfra" do
      ProviderOpenstack.count.should eq 1
      @ems.destroy
      ProviderOpenstack.count.should eq 0
    end

    it "related EmsOpenstack nullifies relation to ProviderOpenstack on EmsOpenstackInfra destroy" do
      # add ems_cloud relation to @ems
      @ems_cloud = FactoryGirl.create(:ems_openstack_with_authentication)
      @ems.provider.cloud_ems << @ems_cloud

      # compare they both use the same provider
      @ems_cloud.provider.should == @ems.provider

      # destroy ems and see the relation of ems_cloud to provider nullified
      @ems.destroy
      ProviderOpenstack.count.should eq 0
      @ems_cloud.reload.provider.should be_nil
    end
  end
end
