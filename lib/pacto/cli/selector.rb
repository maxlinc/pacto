module Pacto
  module CLI
    module Selector
      DEFAULT_LABEL = 'Available choices: '
      DEFAULT_PROMPT = 'Please select from the choices above: '
      DEFAULT_PER_PAGE = 25
      def select(list, question, options = {}, &_blk)
        per_page = options[:per_page] || 25
        prompt = options[:prompt] || '> '
        choice_names, choice_ids = {}, {}
        last_row_id = 0
        say question
        list.each_slice(per_page).with_index do |slice, slice_index |
          print_table(slice.map.with_index do |item, index|
            row_id = 1 + slice_index * per_page + index
            name = block_given? ? yield(item) : item
            choice_names[name] = item
            choice_ids[row_id.to_s] = item
            last_row_id = row_id
            ["#{row_id}.", name]
          end)

          choices = [choice_ids.keys, choice_names.keys].flatten
          unless last_row_id >= list.size
            say '(Press return for more options)'
            choices << ''
          end
          selected = ask_filtered_without_display prompt, nil, limited_to: choices
          return choice_ids[selected] || choice_names[selected] unless selected.empty?
        end

        fail 'No selection made'
      end

      private

      # Modified version of asked filtered, not displaying valid options
      # in []'s since they are listed above (and may be a long list)
      def ask_filtered_without_display(statement, color, options)
        answer_set = options[:limited_to]
        correct_answer = nil
        until correct_answer
          answer = ask_simply(statement, color, options)
          correct_answer = answer_set.include?(answer) ? answer : nil
          say('Your response was not a valid answer. Please try again from the list above.') unless correct_answer
        end
        correct_answer
      end
    end
  end
end
