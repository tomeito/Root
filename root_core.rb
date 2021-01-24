#! /usr/bin/env ruby
# frozen_string_literal: true

require 'strscan'

class RootCore
  @@tokens = {
    '=' => :assign,
    '+' => :add,
    '-' => :sub,
    '*' => :mul,
    '/' => :div,
    '!' => :bang,

    '(' => :lpar,
    ')' => :rpar,
    '{' => :lbrace,
    '}' => :rbrace,

    '==' => :equal,
    '!=' => :not_equal,
    '<' => :less,
    '>' => :greater,
    '<=' => :less_than,
    '>=' => :greater_than,

    ',' => :comma,
    ';' => :semicolon,
    '"' => :quote,

    'fn' => :function,
    'let' => :let,
    'true' => true,
    'false' => false,
    'if' => :if,
    'else' => :else,
    'return' => :return
  }

  @@keywords = [:function, :let, true, false, :if, :else, :return]

  @@environment = {}

  def get_token(regexp)
    return nil if @scanner.eos?

    result = @scanner.scan(regexp)
    result&.strip!
    @@tokens[result] || result
  end

  def unget_token
    @scanner.unscan
  end

  def skip_new_line
    @scanner.scan(/\s*\n+\s*/)
  end

  def parse
    statements
  end

  def statements
    unless s = statement
      raise Exception, 'Statement is not exist.'
    end

    result = [:statements, s]
    skip_new_line
    until @scanner.eos?
      result.append(statement)
      skip_new_line
    end
    result
  end

  def statement
    if get_token(/let\s+/)
      assign_statement
    elsif get_token(/if\s*/)
      if_statement
    elsif get_token(/return\s+/)
      return_statement
    else
      expression_statement
    end
  end

  def expression_statement
    unless e = expression
      raise Exception, 'Expect expression, but not exist.'
    end

    raise Exception, 'Missing ;.' unless get_token(/;/)

    [:expression, e]
  end

  def assign_statement
    unless identifier = get_token(/[a-zA-Z\-_]+/)
      raise Exception, 'Expect identifier, but not exist.'
    end

    raise Exception, 'Missing =.' unless get_token(/\s*=\s*/)

    value = expression
    raise Exception, 'Missing ;.' unless get_token(/;/)

    [:assign, identifier, value]
  end

  def return_statement
    e = expression
    get_token(/;/)
    [:return, e]
  end

  def if_statement
    token = get_token(/\(/)
    raise Exception 'Missing (.' if token != :lpar

    condition = expression
    token = get_token(/\)/)
    raise Exception 'Missing ).' if token != :rpar

    consequence = block
    if get_token(/\s*else\s*/)
      alternative = block
      [:if, condition, consequence, alternative]
    else
      [:if, condition, consequence]
    end
  end

  def expression
    result = sum
    token = get_token(/\s*(==|!=|[<>]=?)\s*/)
    result = [token, result, sum] if token
    result
  end

  def sum
    result = term
    token = get_token(/\s*[+-]\s*/)
    while (token == :add) || (token == :sub)
      result = [token, result, term]
      token = get_token(/\s*[+-]\s*/)
    end
    result
  end

  def term
    result = factor
    token = get_token(%r{\s*[/\*]\s*})
    while (token == :mul) || (token == :div)
      result = [token, result, factor]
      token = get_token(%r{\s*[/\*]\s*})
    end
    result
  end

  def factor
    token = get_token(/\d+|\(|[-!]|fn\s*|"|true|false|[a-zA-Z\-_]+/)
    if /\d+/.match?(token.to_s)
      result = [:integer, token]
    elsif token == :quote
      value = ''
      value.concat(get_token(/./)) until get_token(/"/)
      result = [:string, value]
    elsif [true, false].include?(token)
      result = [:boolean, token]
    elsif token == :lpar
      result = expression
      raise Exception, 'Missing ).' unless get_token(/\)/)
    elsif token == :sub
      result = [:sub, [:integer, '0'], sum]
    elsif token == :bang
      result = [:bang, sum]
    elsif token == :function
      result = [:function, function]
    elsif token
      result = [:identifier, token]
      if get_token(/\(/)
        result = [:call, result]
        arguments = [:arguments]
        until get_token(/\)/)
          arguments.append(expression)
          get_token(/\s*,\s*/)
        end
        result.append(arguments)
      end
    else
      raise Exception, 'Expression Error.'
    end
    result
  end

  def block
    token = get_token(/\s*{\s*/)
    raise Exception, 'Missing {.' if token != :lbrace

    result = [:block]
    skip_new_line
    until get_token(/\s*}\s*/)
      result.append(statement)
      skip_new_line
    end

    result
  end

  def function
    token = get_token(/\(/)
    raise Exception 'Missing (.' if token != :lpar

    parameters = [:parameters]
    until get_token(/\)/)
      parameter = get_token(/[a-zA-Z\-_]+/)
      parameters.append(parameter)
      get_token(/\s*,\s*/)
    end
    b = [:block, block]
    [parameters, b]
  end

  def eval(exp)
    case exp[0]
    when :statements
      exp[1].each do |statement|
        eval(statement)
      end
    when :statement
      eval(exp[1])
    when :assign
    when :return
    when :expression
      eval(exp[1])
    when :add
      eval(exp[1]) + eval(exp[2])
    when :sub
      eval(exp[1]) - eval(exp[2])
    when :mul
      eval(exp[1]) * eval(exp[2])
    when :div
      eval(exp[1]) / eval(exp[2])
    when :bang
      !eval(exp[1])
    when :equal
      eval(exp[1]) == eval(exp[1])
    when :not_equal
      eval(exp[1]) != eval(exp[1])
    when :less
      eval(exp[1]) < eval(exp[1])
    when :greater
      eval(exp[1]) > eval(exp[1])
    when :less_than
      eval(exp[1]) <= eval(exp[1])
    when :greater_than
      eval(exp[1]) >= eval(exp[1])
    when :function
    when :if
    when :integer
      exp[1].to_i
    when :string
      exp[1]
    when :boolean
      exp[1]
    end
  end

  def initialize
    @scanner = StringScanner.new(ARGF.read)
    # p eval parse
    p parse
  end
end

RootCore.new
