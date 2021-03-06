require 'wunderbar'
require 'wunderbar/markdown'

# Define common page features for whimsy tools using bootstrap styles
class Wunderbar::HtmlMarkup

  # Utility function to add icons after form controls
  def _whimsy_forms_iconlink(**args)
    if args[:iconlink]
      _div.input_group_btn do
        _a.btn.btn_default type: 'button', aria_label: "#{iconlabel}", href: "#{args[:iconlink]}", target: 'whimsy_help' do
          _span.glyphicon class: "#{args[:icon]}", aria_label: "#{args[:iconlabel]}"
        end
      end
    elsif args[:icon]
      _span.input_group_addon do
        _span.glyphicon class: "#{args[:icon]}", aria_label: "#{args[:iconlabel]}"
      end
    end
  end

  # Utility function for divs around form controls, including help
  def _whimsy_control_wrapper(**args)
    _div.form_group do
      _label.control_label.col_sm_3 args[:label], for: "#{args[:name]}"
      _div.col_sm_9 do
        _div.input_group do
          yield
          _whimsy_forms_iconlink(args)
        end
        if args[:helptext]
          _span.help_block id: "#{args[:aria_describedby]}" do
            _markdown "#{args[:helptext]}"
          end
        end
      end
    end
  end

  # Display a single input control within a form; or if rows, then a textarea
  # @param name required string ID of control's label/id
  def _whimsy_forms_input(**args)
    return unless args[:name]
    args[:label] ||= 'Enter string'
    args[:type] ||= 'text'
    args[:id] = args[:name]
    args[:aria_describedby] = "#{args[:name]}_help" if args[:helptext]
    _whimsy_control_wrapper(args) do
      args[:class] = 'form-control'
      if args[:rows]
        _textarea! type: args[:type], name: args[:name], id: args[:id], value: args[:value], class: args[:class], aria_describedby: args[:aria_describedby], rows: args[:rows] do
          _! args[:value]
        end
      else
        _input type: args[:type], name: args[:name], id: args[:id], value: args[:value], class: args[:class], aria_describedby: args[:aria_describedby]
      end
    end
  end

  # Display an optionlist control within a form
  # @param name required string ID of control's label/id
  # @param options required ['value'] or {"value" => 'Label for value'} of all selectable values
  # @param values required 'value' or ['value'] or {"value" => 'Label for value'} of all selected values
  # @param placeholder Currently displayed text if passed (not selectable)
  def _whimsy_forms_select(**args)
    return unless args[:name]
    return unless args[:values]
    args[:label] ||= 'Select value(s)'
    args[:id] = args[:name]
    args[:aria_describedby] = "#{args[:name]}_help" if args[:helptext]
    _whimsy_control_wrapper(args) do 
      if args[:multiple]
        args[:multiple] = 'true'
      end
      _select.form_control type: args[:type], name: args[:name], id: args[:id], value: args[:value], aria_describedby: args[:aria_describedby], multiple: args[:multiple] do
        if ''.eql?(args[:placeholder])
          _option '', value: '', selected: 'selected'
        else
          _option "#{args[:placeholder]}", value: '', selected: 'selected', disabled: 'disabled', hidden: 'hidden'
        end
        # Construct selectable list from values (first) then options
        if args[:values].kind_of?(Array)
          args[:values].each do |val|
            _option val, value: val, selected: true
          end
        elsif args[:values].kind_of?(Hash)
          args[:values].each do |val, disp|
            _option disp, value: val, selected: true
          end
        elsif args[:values] # Fallback for simple case of single string value
          _option "#{args[:values]}", value: "#{args[:values]}", selected: true
          args[:values] = [args[:values]] # Ensure supports .include? for options loop below
        end
        if args[:options].kind_of?(Array)
          args[:options].each do |val|
            _option val, value: val unless args[:values].include?(val)
          end
        elsif args[:options].kind_of?(Hash)
          args[:options].each do |val, disp|
            _option disp, value: val unless args[:values].include?(val)
          end
        end
      end
    end
  end

end
