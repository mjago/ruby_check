# frozen_string_literal: false

# RubyCheck - a Ruby class for checking and formatting Ruby code using OpenAI.
#
# This script is licensed under the MIT license. For more information, please see the
# LICENSE file.
#
# Usage: ruby myfile.rb
#
# To use this class in your own code, instantiate a RubyCheck object with the desired
# mode and model, ensuring code to be checked is on the clipboard,
# and will use OpenAI's GPT-3 or Davinci-003 model to provide
# feedback and corrections.
#
# Example usage:
#   checker = RubyCheck.new(:comment, :davinci003)
#   checker.openai_call
#
# For more information and documentation, please see the README file.
#
# Dependencies: Rouge, Colorize, OpenAI API

require 'rouge'
require 'openai'
require 'colorize'

class RubyCheck
  def initialize(mode, model)
    OpenAI.configure do |config|
      config.access_token = ENV.fetch('OPENAI_API_KEY')
    end
    @client = OpenAI::Client.new
    @mode = mode.to_s
    @model = model_select(model)
  end

  def model_select(model)
    case model
    when :davinci003 then 'text-davinci-003'
    else 'gpt-3.5-turbo'
    end
  end

  def tick
    "\u{2714}".encode('utf-8').colorize(:green)
  end

  def delim
    "\n\e[31m" + "~" * 20 + "\e[0m\n"
  end

  def clipboard
    `xclip -o -selection clipboard`
  end

  def code_preview(text)
    delim + text.colorize(:yellow) + delim
  end

  def no_response
    "\e[31m" + "No response!!" + "\e[0m"
  end

  def valid_response?(res)
    res['finish_reason'] == 'stop'
  end

  def valid_tick
    "Valid Response: " + tick
  end

  def error(msg)
    "\e[31m ERROR! \e[0m\n" +
    "\e[31m   type: #{msg['type']} \e[0m\n" +
      "\e[31m   message: #{msg['message']} \e[0m\n"
  end

  def formatted(code)
    formatter = Rouge::Formatters::Terminal256.new
    lexer = Rouge::Lexers::Ruby.new
    formatter.format(lexer.lex(code))
  end

  def valid_response(res)
    out = ''
    out += valid_tick if valid_response?(res)
    text = res["text"]
    code = text.match(/```ruby\n(.*)```/m)&.[](1)
    fout = formatted(code) if code
    if fout
      out += "#{delim} #{fout} #{delim}"
    else
      out += text.colorize(:blue)
    end
    out
  end

  def prompt
    "Can you #{@mode} Ruby code: `#{@text}`?"
  end

  def openai_call
    out = ''
    # Get the text currently on the clipboard
    @text = clipboard
    out << code_preview(@text)

    @response = @client.completions(
      parameters: {
        model: @model,
        max_tokens: 4097 - prompt.size,
        prompt: prompt
      })

    pp @response

    if @response['error']
      puts error(@response['error'])
      exit 1
    end

    if @response && @response['choices'][0]
      out << valid_response(@response['choices'][0])
    else
      out << no_response
    end
    out
  end
end

if __FILE__ == $0
  RubyCheck.new(:comment, :davinci003).openai_call
end
