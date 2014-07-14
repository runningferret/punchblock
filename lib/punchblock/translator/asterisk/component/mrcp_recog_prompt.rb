# encoding: utf-8

require 'punchblock/translator/asterisk/unimrcp_app'

module Punchblock
  module Translator
    class Asterisk
      module Component
        module MRCPRecogPrompt
          UniMRCPError = Class.new Punchblock::Error

          DEFAULT_UNIMRCP_APP_OPTIONS = { uer: 1, b: 0, t: 5000, nit: -1, dit: -1}.freeze

          def execute
            setup_defaults
            validate
            send_ref
            execute_unimrcp_app
            complete
          rescue ChannelGoneError
            call_ended
          rescue UniMRCPError
            complete_with_error 'Terminated due to UniMRCP error'
          rescue RubyAMI::Error => e
            complete_with_error "Terminated due to AMI error '#{e.message}'"
          rescue OptionError => e
            with_error 'option error', e.message
          end

          private

          def validate
            [:interrupt_on, :start_offset, :start_paused, :repeat_interval, :repeat_times, :max_time].each do |opt|
              raise OptionError, "A #{opt} value is unsupported on Asterisk." if output_node.send opt
            end

            raise OptionError, "An initial-timeout value must be -1 or a positive integer." if @initial_timeout < -1
            raise OptionError, "An inter-digit-timeout value must be -1 or a positive integer." if @inter_digit_timeout < -1
          end

          def execute_app(app, *args)
            UniMRCPApp.new(app, *args, unimrcp_app_options).execute @call
            raise UniMRCPError if @call.channel_var('RECOG_STATUS') == 'ERROR'
          end

          def unimrcp_app_options
            opts        = DEFAULT_UNIMRCP_APP_OPTIONS.dup
            opts[:b]    = 1 if @component_node.barge_in
            opts[:t]    = @recognition_timeout
            opts[:nit]  = @initial_timeout
            opts[:dit]  = @inter_digit_timeout
            opts[:dttc] = @terminator  if @terminator
            opts[:sl]   = @sensitivity if @sensitivity
            return opts
          end

          def set_sensitivity
            @sensitivity = input_node.sensitivity
          end

          def set_terminator
            @terminator = input_node.terminator
          end

          def set_recognition_timeout
            @recognition_timeout = input_node.recognition_timeout || -1
          end

          def set_initial_timeout
            @initial_timeout = input_node.initial_timeout || -1
          end

          def set_inter_digit_timeout
            @inter_digit_timeout = input_node.inter_digit_timeout || -1
          end

          def setup_defaults
            set_recognition_timeout
            set_initial_timeout
            set_inter_digit_timeout
            set_sensitivity
            set_terminator
          end

          def grammars
            input_node.grammars.map do |d|
              if d.content_type
                d.value.to_doc.to_s
              else
                d.url
              end
            end.join ','
          end

          def first_doc
            output_node.render_documents.first
          end

          def audio_filename
            first_doc.value.first
          end

          def output_node
            @component_node.output
          end

          def input_node
            @component_node.input
          end

          def complete
            send_complete_event case @call.channel_var('RECOG_COMPLETION_CAUSE')
            when '000'
              nlsml = RubySpeech.parse URI.decode(@call.channel_var('RECOG_RESULT'))
              Punchblock::Component::Input::Complete::Match.new nlsml: nlsml
            when '001'
              Punchblock::Component::Input::Complete::NoMatch.new
            when '002'
              Punchblock::Component::Input::Complete::NoInput.new
            when '015'
              pb_logger.debug "Recieved a response code of 015! Call was #{@call.inspect}"
              Punchblock::Component::Input::Complete::NoMatch.new
            end
          end
        end
      end
    end
  end
end
