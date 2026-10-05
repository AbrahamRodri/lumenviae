defmodule LumenViae.Ops.ProbesTest do
  @moduledoc """
  The real S3 and Office engine probes, which the rest of the suite answers
  from config (`:ops_probe_answers` in config/test.exs). Not async: the
  answers, the S3 client and the Req.Test stub are all shared, the stub
  because the probe asks from a task of its own.
  """
  use ExUnit.Case, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 3]

  alias LumenViae.Office.DivinumOfficium
  alias LumenViae.Ops.Probes

  @fixtures Path.expand("../../support/fixtures/divinum_officium", __DIR__)

  setup do
    put_env(:lumen_viae, :ops_probe_answers, %{})
    Req.Test.set_req_test_to_shared()
    on_exit(fn -> Req.Test.set_req_test_to_private() end)
  end

  test "config answers a probe at once, without asking anybody" do
    put_env(:lumen_viae, :ops_probe_answers, %{s3: %{status: :ok, detail: "from config"}})
    assert Probes.run(:s3) == %{status: :ok, detail: "from config", ms: 0}
  end

  describe "S3" do
    test "is reachable when the bucket answers a HEAD" do
      put_env(:ex_aws, :http_client, LumenViae.Test.FakeAwsHttpClient)
      put_env(:ex_aws, :access_key_id, "test-key")
      put_env(:ex_aws, :secret_access_key, "test-secret")
      put_env(:lumen_viae, :fake_aws_test_pid, self())

      assert %{status: :ok, detail: detail} = Probes.run(:s3)
      assert detail =~ "reachable"
      assert_received {:aws_request, :head, _url, _body}
    end

    test "fails without credentials" do
      put_env(:ex_aws, :access_key_id, nil)
      assert %{status: :error} = Probes.run(:s3)
    end
  end

  describe "the Office engine" do
    test "is reachable when it answers the calendar" do
      html = File.read!(Path.join(@fixtures, "kalendar_2026-08.html"))
      Req.Test.stub(DivinumOfficium, &Req.Test.html(&1, html))

      assert %{status: :ok} = Probes.run(:office_engine)
    end

    test "fails when it does not" do
      Req.Test.stub(DivinumOfficium, &Plug.Conn.send_resp(&1, 503, "down"))
      assert %{status: :error} = Probes.run(:office_engine)
    end

    test "is given up on after the timeout, never waited for" do
      Req.Test.stub(DivinumOfficium, fn conn ->
        Process.sleep(500)
        Plug.Conn.send_resp(conn, 200, "")
      end)

      assert %{status: :error, detail: "no answer within 50 ms", ms: ms} =
               Probes.run(:office_engine, timeout: 50)

      assert ms < 400
    end
  end
end
