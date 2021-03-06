defmodule Plug.SSLTest do
  use ExUnit.Case, async: true
  use Plug.Test

  defp call(conn, opts \\ []) do
    Plug.SSL.call(conn, Plug.SSL.init(opts))
  end

  test "HSTS headers by default" do
    conn = call(conn(:get, "https://example.com/"))
    assert get_resp_header(conn, "strict-transport-security") == ["max-age=31536000"]
    refute conn.halted
  end

  test "HSTS is true" do
    conn = call(conn(:get, "https://example.com/"), hsts: true)
    assert get_resp_header(conn, "strict-transport-security") == ["max-age=31536000"]
    refute conn.halted
  end

  test "HSTS is false" do
    conn = call(conn(:get, "https://example.com/"), hsts: false)
    assert get_resp_header(conn, "strict-transport-security") == []
    refute conn.halted
  end

  test "HSTS custom expires" do
    conn = call(conn(:get, "https://example.com/"), expires: 3600)
    assert get_resp_header(conn, "strict-transport-security") == ["max-age=3600"]
    refute conn.halted
  end

  test "HSTS include subdomains" do
    conn = call(conn(:get, "https://example.com/"), subdomains: true)

    assert get_resp_header(conn, "strict-transport-security") ==
             ["max-age=31536000; includeSubDomains"]

    refute conn.halted
  end

  test "HSTS include preload" do
    conn = call(conn(:get, "https://example.com/"), preload: true)
    assert get_resp_header(conn, "strict-transport-security") == ["max-age=31536000; preload"]
    refute conn.halted
  end

  test "HSTS with multiple flags" do
    conn = call(conn(:get, "https://example.com/"), preload: true, subdomains: true)

    assert get_resp_header(conn, "strict-transport-security") ==
             ["max-age=31536000; preload; includeSubDomains"]

    refute conn.halted
  end

  test "rewrites conn http to https based on x-forwarded-proto" do
    conn =
      conn(:get, "http://example.com/")
      |> put_req_header("x-forwarded-proto", "https")
      |> call(rewrite_on: [:x_forwarded_proto])

    assert get_resp_header(conn, "strict-transport-security") == ["max-age=31536000"]
    refute conn.halted
  end

  test "redirects to host when insecure" do
    conn = call(conn(:get, "http://example.com/"))
    assert get_resp_header(conn, "location") == ["https://example.com/"]
    assert conn.halted

    conn = call(conn(:get, "http://example.com/foo?bar=baz"))
    assert get_resp_header(conn, "location") == ["https://example.com/foo?bar=baz"]
    assert conn.halted
  end

  test "redirects to custom host on get" do
    conn = call(conn(:get, "http://example.com/"), host: "ssl.example.com:443")
    assert get_resp_header(conn, "location") == ["https://ssl.example.com:443/"]
    assert conn.status == 301
    assert conn.halted
  end

  test "redirects to tuple host on get" do
    System.put_env("PLUG_SSL_HOST", "ssl.example.com:443")
    conn = call(conn(:get, "http://example.com/"), host: {System, :get_env, ["PLUG_SSL_HOST"]})
    assert get_resp_header(conn, "location") == ["https://ssl.example.com:443/"]
    assert conn.status == 301
    assert conn.halted
  end

  test "redirects to host on head" do
    conn = call(conn(:head, "http://example.com/"))
    assert conn.status == 301
    assert conn.halted
  end

  test "redirects to custom host with other verbs" do
    for method <- ~w(options post put delete patch)a do
      conn = call(conn(method, "http://example.com/"))
      assert conn.status == 307
      assert conn.halted
    end
  end
end
