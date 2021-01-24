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

  def skip_new_line
    @scanner.scan(/\s*\n+\s*/)
  end

  def parse_program
    parse_statements
  end

  def parse_statements
    unless s = parse_statement
      raise Exception, 'Statement is not exist.'
    end

    result = [:statements, s]
    skip_new_line
    until @scanner.eos?
      result.append(parse_statement)
      skip_new_line
    end
    result
  end

  def parse_statement
    if get_token(/let\s+/)
      parse_assign_statement
    elsif get_token(/if\s*/)
      parse_if_statement
    elsif get_token(/return\s+/)
      parse_return_statement
    else
      parse_expression_statement
    end
  end

  def parse_expression_statement
    unless e = parse_expression
      raise Exception, 'Expect expression, but not exist.'
    end

    raise Exception, 'Missing ;.' unless get_token(/;/)

    [:expression, e]
  end

  def parse_assign_statement
    unless identifier = get_token(/[a-zA-Z\-_]+/)
      raise Exception, 'Expect identifier, but not exist.'
    end

    raise Exception, 'Missing =.' unless get_token(/\s*=\s*/)

    value = parse_expression
    raise Exception, 'Missing ;.' unless get_token(/;/)

    [:assign, identifier, value]
  end

  def parse_return_statement
    e = parse_expression
    get_token(/;/)
    [:return, e]
  end

  def parse_if_statement
    token = get_token(/\(/)
    raise Exception 'Missing (.' if token != :lpar

    condition = parse_expression
    token = get_token(/\)/)
    raise Exception 'Missing ).' if token != :rpar

    consequence = parse_block
    if get_token(/\s*else\s*/)
      alternative = parse_block
      [:if, condition, consequence, alternative]
    else
      [:if, condition, consequence]
    end
  end

  def parse_expression
    result = parse_sum
    token = get_token(/\s*(==|!=|[<>]=?)\s*/)
    result = [token, result, parse_sum] if token
    result
  end

  def parse_sum
    result = parse_term
    token = get_token(/\s*[+-]\s*/)
    while (token == :add) || (token == :sub)
      result = [token, result, parse_term]
      token = get_token(/\s*[+-]\s*/)
    end
    result
  end

  def parse_term
    result = parse_factor
    token = get_token(%r{\s*[/\*]\s*})
    while (token == :mul) || (token == :div)
      result = [token, result, parse_factor]
      token = get_token(%r{\s*[/\*]\s*})
    end
    result
  end

  def parse_factor
    token = get_token(/\d+|\(|[-!]|fn\s*|"|true|false|[a-zA-Z\-_]+/)
    if /\d+/.match?(token.to_s)
      result = [:integer, token]
    elsif token == :quote
      result = parse_string
    elsif [true, false].include?(token)
      result = [:boolean, token]
    elsif token == :lpar
      result = parse_expression
      raise Exception, 'Missing ).' unless get_token(/\)/)
    elsif token == :sub
      result = [:sub, [:integer, '0'], parse_sum]
    elsif token == :bang
      result = [:bang, parse_sum]
    elsif token == :function
      param, block = parse_function
      result = [:function, param, block]
    elsif token
      result = parse_indentifier(token)
    else
      raise Exception, 'Expression Error.'
    end
    result
  end

  def parse_string
    value = ''
    value.concat(get_token(/./)) until get_token(/"/)
    [:string, value]
  end

  def parse_indentifier(token)
    result = [:identifier, token]
    if get_token(/\(/)
      result = [:call, result]
      arguments = [:arguments]
      until get_token(/\)/)
        arguments.append(parse_expression)
        get_token(/\s*,\s*/)
      end
      result.append(arguments)
    end
    result
  end

  def parse_function
    token = get_token(/\(/)
    raise Exception 'Missing (.' if token != :lpar

    parameters = [:parameters]
    until get_token(/\)/)
      parameter = get_token(/[a-zA-Z\-_]+/)
      parameters.append(parameter)
      get_token(/\s*,\s*/)
    end
    [parameters, parse_block]
  end

  def parse_block
    token = get_token(/\s*{\s*/)
    raise Exception, 'Missing {.' if token != :lbrace

    result = [:block]
    skip_new_line
    until get_token(/\s*}\s*/)
      result.append(parse_statement)
      skip_new_line
    end

    result
  end

  def eval(exp, env)
    case exp[0]
    when :statements
      eval_statements(exp, env)
    when :statement
      eval(exp[1], env)
    when :expression
      eval(exp[1], env)
    when :assign
      eval_assingment(exp, env)
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
      eval_call(exp, env)
    when :if
      eval_if(exp, env)
    when :block
      eval_block(exp, env)
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

  def eval_statements(exp, env)
    exp.drop(1).each do |statement|
      result, is_return = eval(statement, env)
      return result if is_return
    end
  end

  def eval_assingment(exp, env)
    raise Exception, 'Identifier contains a reserved word.' if @@keywords.include?(exp[1])

    register_params(exp[1], exp[2]) if exp[2][0] == :function
    env.set(exp[1], eval(exp[2], env))
    nil
  end

  def eval_call(exp, env)
    name = exp[1][1]
    args = exp[2].clone.drop(1)

    outer = env
    env = Environment.new_enclosed(outer)
    @@params_heap[name].zip(args).each do |param, arg|
      env.set(param, eval(arg, outer))
    end

    function_block = eval(exp[1], env)
    eval(function_block, env)
  end

  def eval_if(exp, env)
    outer = env
    env = Environment.new_enclosed(outer)
    if eval(exp[1], outer)
      eval(exp[2], env)
    elsif exp[3]
      eval(exp[3], env)
    end
  end

  def eval_block(exp, env)
    statements = exp.drop(1)
    statements.each do |statement|
      result, is_return = eval(statement, env)
      return result if is_return
    end
    result
  end

  def register_params(name, function)
    params = function[1].drop(1)
    @@params_heap[name] = params
  end

  def initialize
    @scanner = StringScanner.new(ARGF.read)
    env = Environment.new
    eval(parse_program, env)
    # p parse
  end
end

RootCore.new
