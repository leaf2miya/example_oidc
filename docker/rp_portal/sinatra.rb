require 'rubygems'
require 'sinatra'
require 'omniauth'
require 'omniauth_openid_connect'
require 'faraday'
require 'jwt'
require 'json'

class SinatraApp < Sinatra::Base
  configure do
    set :bind, '0.0.0.0'
    set :port, 3000
    set :inline_template, true
    $stdout.sync = true # debug
  end

  helpers do
    def decode_jwt(str)
      JSON.pretty_generate(JWT.decode(str, nil, false))
    end
  end

  use Rack::Session::Pool
  use OmniAuth::Builder do
    # setup provider client options
    cl_options = {
      identifier: ENV['IDENTIFIER'],
      secret: ENV['SECRET'],
      redirect_uri: ENV['REDIRECT_URI']
    }
    %w(scheme host port authorization_endpoint token_endpoint userinfo_endpoint jwks_uri end_session_endpoint).each do |key|
      env_key = key.upcase
      next unless ENV.key? env_key
      cl_options[key.to_sym] = key == 'port' ? ENV[env_key].to_i : ENV[env_key]
    end

    # setup provider options
    options = {
      issuer: ENV['ISSUER'],
      response_type: 'code', #=> code: Authentication flow, id_token token: implicit flow
      client_options: cl_options
    }
    %w(
      discovery client_signing_alg client_jwk_signing_key
      client_x509_signing_key scope response_type state response_mode
      display prompt hd max_age ui_locales id_token_hint acr_values send_nonce
      send_scope_to_token_endpoint client_auth_method post_logout_redirect_uri
      extra_authorize_params uid_field
    ).each do |key|
      env_key = key.upcase
      next unless ENV.key? env_key
      if %w(discovery send_nonce send_scope_to_token_endpoint).include? key
        # type: boolean
        val = case ENV[env_key].downcase
              when 'true' then true
              when 'false' then false
              else nil
              end
        next val.nil?
        options[key.to_sym] = val
      elsif %w(scope response_type response_mode display prompt).include? key
        # type: Array
        arr = ENV[env_key].split(',')
        val = if key == 'response_type'
                # Array<String>
                arr
              else
                # Array<Symbol>
                arr.map(&:to_sym)
              end
        options[key.to_sym] = val
      elsif key == 'client_x509_signing_key'
        # exchange PEM
        options[key.to_sym] = "-----BEGIN CERTIFICATE-----\r\n#{ENV[env_key]}\r\n-----END CERTIFICATE-----"
      elsif key == 'client_signing_alg'
        # type: simbol
        options[key.to_sym] = ENV[env_key].to_sym
      else
        options[key.to_sym] = ENV[env_key]
      end
    end

    provider :openid_connect, options
  end

  before '/backend/*' do
    @conn = Faraday.new(url: 'http://sp3:3000/') do |conn|
      conn.request :url_encoded
      conn.response :logger
      conn.adapter Faraday.default_adapter
    end
  end

  get '/' do
    erb "<a href='/auth/openid_connect'>try openid connect</a>"
  end

  get '/auth/:provider/callback' do
    session['omniauth.auth'] = request.env['omniauth.auth']
    erb <<~EOS
      <a href='/oidc/userinfo'>show userinfo</a><br>
      <a href='/backend/api/header'>call backend api(token set: Authorization Header)</a><br>
      <a href='/backend/api/form'>call backend api(token set: form parameter)</a><br>
      <a href='/backend/api/query'>call backend api(token set: query-string)</a><br>
      <a href='/auth/refresh'>refresh token</a><br>
      <a href='/auth/openid_connect/logout'>logout</a><br>
      <ul>
      <li>
        <p>ID Token</p>
        <p>#{session['omniauth.auth']['credentials']['id_token']}</p>
      </li>
      <li>
        <p>Access Token</p>
        <p>#{session['omniauth.auth']['credentials']['token']}</p>
      </li>
      <li>
        <p>Refresh Token</p>
        <p>#{session['omniauth.auth']['credentials']['refresh_token']}</p>
      </li>
      <li>
        <p>ID Token(decord)</p>
        <pre>#{decode_jwt(session['omniauth.auth']['credentials']['id_token'])}</pre>
      </li>
      <li>
        <p>Access Token(decord)</p>
        <pre>#{decode_jwt(session['omniauth.auth']['credentials']['token'])}</pre>
      </li>
      </ul>
    EOS
  end

  get '/backend/api/:type' do
    # call api example
    #
    # Three ways to send token (from RFC6750)
    # Authorization Header (RFC6750 2.1)
    # access_token form parameter (RFC6750 2.2)
    # access_token query parameter (RFC6750 2.2)
    res = @conn.post do |req|
      query = if params[:type] == 'query'
                { access_token: session['omniauth.auth']['credentials']['token'] }
              else
                {}
              end
      req.url '/api', query
      if params[:type] == 'header'
        req.headers['Authorization'] = "Bearer #{session['omniauth.auth']['credentials']['token']}"
      elsif params[:type] == 'form'
        req.body = {
          access_token: session['omniauth.auth']['credentials']['token'],
        }
      end

      req.options.timeout = 20
      req.options.open_timeout = 5
    end
    res.body
  end

  get '/auth/failure' do
    # authentication failed
    "authentication failed. params: #{params.inspect}"
  end

  get '/auth/logout' do
    # after logout
    erb <<~EOS
      <p>Logout Successful</p><br>
      <a href='/'>Go Top</a>
    EOS
  end

  get '/auth/refresh' do
    # refresh token
    # omniauth_openid_connect does not supported refresh_token grant
    # (see https://github.com/m0n9oose/omniauth_openid_connect#additional-configuration-notes)
    redirect '/auth/openid_connect'
  end

  get '/oidc/userinfo' do
    url = "#{ENV['SCHEME']}://#{ENV['HOST']}:#{ENV['PORT']}#{ENV['USERINFO_ENDPOINT']}"
    conn = Faraday.new(url: url) do |conn|
      conn.request :url_encoded
      conn.response :logger
      conn.adapter Faraday.default_adapter
    end
    res = conn.get do |req|
      req.headers['Authorization'] = "Bearer #{session['omniauth.auth']['credentials']['token']}"
    end
    if res.status == 200
      erb <<~EOS
        <p>UserInfo</p>
        <pre>#{JSON.pretty_generate(JSON.parse(res.body))}</pre>
      EOS
    else
      "error occurred"
    end
  end
end

SinatraApp.run! if __FILE__ == $0
