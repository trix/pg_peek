require "test_helper"
require "minitest/mock"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "serves without credentials in a local environment" do
    get pg_peek.databases_path

    assert_response :success
  end

  test "refuses to serve outside local environments when nothing is configured" do
    in_deployed_environment do
      get pg_peek.databases_path
    end

    assert_response :forbidden
    assert_select "article[aria-label='Authentication is not configured']" do
      assert_select "code", text: /PG_PEEK_USERNAME/
      assert_select "code", text: /public_dashboard/
    end
  end

  test "serves outside local environments when the dashboard is declared public" do
    with_config(public_dashboard: true) do
      in_deployed_environment do
        get pg_peek.databases_path
      end
    end

    assert_response :success
  end

  test "challenges for credentials when they are configured" do
    with_config(username: "peek", password: "s3cret") do
      get pg_peek.databases_path
    end

    assert_response :unauthorized
  end

  test "serves when the configured credentials are given" do
    with_config(username: "peek", password: "s3cret") do
      get pg_peek.databases_path, headers: basic_auth_header("peek", "s3cret")
    end

    assert_response :success
  end

  test "rejects wrong credentials" do
    with_config(username: "peek", password: "s3cret") do
      get pg_peek.databases_path, headers: basic_auth_header("peek", "wrong")
    end

    assert_response :unauthorized
  end

  test "configured credentials apply in local environments too" do
    # A tunnelled development server is reachable, so credentials must not be
    # skipped just because the environment is local.
    with_config(username: "peek", password: "s3cret") do
      get pg_peek.databases_path
    end

    assert_response :unauthorized
  end

  private

  def basic_auth_header(username, password)
    { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(username, password) }
  end

  def in_deployed_environment(&block)
    Rails.env.stub(:local?, false, &block)
  end

  def with_config(attributes)
    config = Rails.application.config.pg_peek
    original = attributes.keys.index_with { |key| config.public_send(key) }
    attributes.each { |key, value| config.public_send("#{key}=", value) }
    yield
  ensure
    original&.each { |key, value| config.public_send("#{key}=", value) }
  end
end
