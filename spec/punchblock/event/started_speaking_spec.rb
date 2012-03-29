# encoding: utf-8

require 'spec_helper'

module Punchblock
  class Event
    describe StartedSpeaking do
      it 'registers itself' do
        RayoNode.class_from_registration(:'started-speaking', 'urn:xmpp:rayo:1').should be == StartedSpeaking
      end

      describe "from a stanza" do
        let :stanza do
          '<started-speaking xmlns="urn:xmpp:rayo:1" call-id="x0yz4ye-lx7-6ai9njwvw8nsb"/>'
        end

        subject { RayoNode.import parse_stanza(stanza).root, '9f00061', '1' }

        it { should be_instance_of StartedSpeaking }

        it_should_behave_like 'event'

        its(:other_call_id) { should be == "x0yz4ye-lx7-6ai9njwvw8nsb" }
        its(:xmlns)         { should be == 'urn:xmpp:rayo:1' }
      end

      describe "when setting options in initializer" do
        subject do
          StartedSpeaking.new :other_call_id => 'abc123'
        end

        its(:other_call_id) { should be == 'abc123' }
      end
    end
  end
end # Punchblock
