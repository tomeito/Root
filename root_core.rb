#! /usr/bin/env ruby

require 'strscan'
require './enviroment.rb'

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

  @@params_heap = {}

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
      param, block = function
      result = [:function, param, block]
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
    [parameters, block]
  end

  def eval(exp, env)
    case exp[0]
    when :statements
      exp.drop(1).each do |statement|
        result, is_return = eval(statement, env)
        return result if is_return
      end
    when :statement
      eval(exp[1], env)
    when :expression
      eval(exp[1], env)
    when :assign
      raise Exception, 'Identifier contains a reserved word.' if @@keywords.include?(exp[1])

      register_params(exp[1], exp[2]) if exp[2][0] == :function
      env.set(exp[1], eval(exp[2], env))
      nil
    when :return
      result = eval(exp[1], env)
      [result, true]
    when :add
      eval(exp[1], env) + eval(exp[2], env)
    when :sub
      eval(exp[1], env) - eval(exp[2], env)
    when :mul
      eval(exp[1], env) * eval(exp[2], env)
    when :div
      eval(exp[1], env) / eval(exp[2], env)
    when :bang
      !eval(exp[1], env)
    when :equal
      eval(exp[1], env) == eval(exp[2], env)
    when :not_equal
      eval(exp[1], env) != eval(exp[2], env)
    when :less
      eval(exp[1], env) < eval(exp[2], env)
    when :greater
      eval(exp[1], env) > eval(exp[2], env)
    when :less_than
      eval(exp[1], env) <= eval(exp[2], env)
    when :greater_than
      eval(exp[1], env) >= eval(exp[2], env)
    when :function
      exp[2]
    when :call
      name = exp[1][1]
      args = exp[2].clone.drop(1)

      outer = env
      env = Environment.new_enclosed(outer)
      @@params_heap[name].zip(args).each do |param, arg|
        env.set(param, eval(arg, outer))
      end

      function_block = eval(exp[1], env)
      eval(function_block, env)
    when :if
      outer = env
      env = Environment.new_enclosed(outer)
      if eval(exp[1], outer)
        eval(exp[2], env)
      elsif exp[3]
        eval(exp[3], env)
      end
    when :block
      statements = exp.drop(1)
      statements.each do |statement|
        result, is_return = eval(statement, env)
        return result if is_return
      end
      result
    when :integer
      exp[1].to_i
    when :string
      exp[1]
    when :boolean
      exp[1]
    when :identifier
      env.get(exp[1])
    end
  end

  def register_params(name, function)
    params = function[1].drop(1)
    @@params_heap[name] = params
  end

  def initialize
    @scanner = StringScanner.new(ARGF.read)
    env = Environment.new
    eval(parse, env)
    # p parse
  end
end

RootCore.new
