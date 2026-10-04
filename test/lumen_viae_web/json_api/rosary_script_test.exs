defmodule LumenViaeWeb.JsonApi.RosaryScriptTest do
  @moduledoc """
  The order a Rosary is said in, over `/api/v2`: the templates in the
  content document's `script` section, and `GET /rosary-script`, their
  expansion.

  The property that matters is that the two are one thing. A client prays
  offline from the templates, so this test expands them the way a client
  would, from the JSON as served and following only what
  docs/SPOKEN_ROSARY.md says about them, and holds the result to
  `PrayerAudio.script/3` and to `GET /rosary-script`, for every category,
  every style and every set of optional prayers.
  """
  use LumenViaeWeb.ConnCase, async: true

  import LumenViaeWeb.JsonApiHelpers

  alias LumenViae.Rosary.PrayerAudio

  @categories ~w(joyful sorrowful glorious luminous seven_sorrows)
  @styles ~w(meditation scriptural plain)

  # Every subset of the optional prayers, each in an order of its own, so
  # the expansion is seen to put them in their order, not the order given.
  @extra_sets for a <- [[], ["st_michael"]],
                  b <- [[], ["holy_father"]],
                  c <- [[], ["memorare"]],
                  do: a ++ b ++ c

  defp templates(conn) do
    conn
    |> get_v2("/rosary-content?fields[rosary_content]=script")
    |> v2_response(200)
    |> get_in(["data", "attributes", "script"])
  end

  defp orders("seven_sorrows"), do: Enum.to_list(1..7)
  defp orders(_category), do: Enum.to_list(1..5)

  # A client's expansion, from the served templates alone: the form whose
  # categories hold the category; its opening; each decade, its steps in
  # the style chosen, the run marked per_bead said for each Hail Mary;
  # its closing, the chosen optional prayers in the order listed if the
  # form takes them, and its final steps.
  defp expand_like_a_client(script, category, style, extras, orders) do
    form = Enum.find([script["rosary"], script["chaplet"]], &(category in &1["categories"]))
    hail_marys = form["strand"]["hail_marys"]

    chosen =
      if form["takes_extras"],
        do:
          for(
            extra <- script["closing_extras"],
            extra["id"] in extras,
            step <- extra["steps"],
            do: step
          ),
        else: []

    decades =
      for {order, decade} <- Enum.with_index(orders),
          step <- said(form["decade"], style, hail_marys) do
        {template, n} = step
        key = "#{category}_#{order}"

        %{
          "kind" => template["kind"],
          "name" =>
            case template["kind"] do
              "prayer" -> template["prayer_id"]
              "verse" -> "#{key}_#{n}"
              _ -> key
            end,
          "mystery" => key,
          "phase" => "decade",
          "decade" => decade,
          "bead" => if(n, do: n, else: template["bead"]),
          "place" => template["place"],
          "caption" =>
            if(n,
              do: String.replace(template["caption"], "{n}", "#{n}"),
              else: template["caption"]
            ),
          "pause_ms" => template["pause_ms"]
        }
      end

    on_pendant(form["opening"], "opening") ++
      decades ++ on_pendant(form["closing"] ++ chosen ++ form["final"], "closing")
  end

  # The decade's templates in one style, each paired with its Hail Mary's
  # number when it is said on every bead.
  defp said(template, style, hail_marys) do
    template
    |> Enum.filter(&(&1["style"] == nil or &1["style"] == style))
    |> walk(hail_marys)
  end

  defp walk([], _hail_marys), do: []

  defp walk([%{"per_bead" => true} | _] = steps, hail_marys) do
    {run, rest} = Enum.split_while(steps, & &1["per_bead"])
    Enum.flat_map(1..hail_marys, fn n -> Enum.map(run, &{&1, n}) end) ++ walk(rest, hail_marys)
  end

  defp walk([step | rest], hail_marys), do: [{step, nil} | walk(rest, hail_marys)]

  defp on_pendant(steps, phase) do
    for step <- steps do
      %{
        "kind" => step["kind"],
        "name" => step["prayer_id"],
        "mystery" => nil,
        "phase" => phase,
        "decade" => nil,
        "bead" => step["bead"],
        "place" => step["place"],
        "caption" => step["caption"],
        "pause_ms" => step["pause_ms"]
      }
    end
  end

  # PrayerAudio.script/3, as JSON spells it.
  defp server_script(category, style, extras) do
    category
    |> PrayerAudio.script(orders(category), style: style, closing: extras)
    |> Enum.map(fn step ->
      step
      |> Map.update!(:kind, &Atom.to_string/1)
      |> Map.update!(:phase, &Atom.to_string/1)
      |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)
    end)
  end

  defp steps(conn, query) do
    conn
    |> get_v2("/rosary-script?" <> query)
    |> v2_response(200)
    |> get_in(["data", "attributes", "steps"])
  end

  test "expanding the templates as a client would gives exactly the server's script, every time",
       %{conn: conn} do
    script = templates(conn)

    for category <- @categories, style <- @styles, extras <- @extra_sets do
      expected = server_script(category, style, extras)
      expanded = expand_like_a_client(script, category, style, extras, orders(category))

      assert expanded == expected, "#{category}, #{style}, #{inspect(extras)}"

      served =
        steps(
          build_conn(),
          "category=#{category}&style=#{style}&extras=#{Enum.join(extras, ",")}"
        )

      assert served == expected, "GET /rosary-script: #{category}, #{style}, #{inspect(extras)}"
    end
  end

  test "a set's own mysteries expand the same way", %{conn: conn} do
    script = templates(conn)

    expected =
      "sorrowful"
      |> PrayerAudio.script([3, 4, 5], style: :scriptural)
      |> length()

    expanded = expand_like_a_client(script, "sorrowful", "scriptural", [], [3, 4, 5])
    assert length(expanded) == expected
    assert Enum.find(expanded, &(&1["phase"] == "decade"))["mystery"] == "sorrowful_3"

    assert steps(conn, "category=sorrowful&style=scriptural&orders=3,4,5") == expanded
  end

  describe "GET /rosary-script" do
    test "with a category alone is that category's Rosary with meditations, every mystery", %{
      conn: conn
    } do
      data =
        conn |> get_v2("/rosary-script?category=joyful") |> v2_response(200) |> Map.fetch!("data")

      assert %{
               "type" => "rosary_script",
               "id" => "joyful:meditation::1,2,3,4,5",
               "attributes" => %{
                 "category" => "joyful",
                 "style" => "meditation",
                 "extras" => [],
                 "orders" => [1, 2, 3, 4, 5]
               }
             } = data

      assert length(data["attributes"]["steps"]) == 85
    end

    test "counts what the app counts", %{conn: conn} do
      assert length(steps(conn, "category=glorious&style=plain")) == 80
      assert length(steps(conn, "category=glorious&style=scriptural")) == 130
      assert length(steps(conn, "category=seven_sorrows")) == 84
      assert length(steps(conn, "category=luminous&extras=holy_father,memorare,st_michael")) == 90

      assert length(steps(conn, "category=seven_sorrows&extras=holy_father,memorare,st_michael")) ==
               84
    end

    test "names the optional prayers it says, in the order they are said", %{conn: conn} do
      attributes =
        conn
        |> get_v2("/rosary-script?category=joyful&extras=st_michael,holy_father")
        |> v2_response(200)
        |> get_in(["data", "attributes"])

      assert attributes["extras"] == ["holy_father", "st_michael"]

      chaplet =
        build_conn()
        |> get_v2("/rosary-script?category=seven_sorrows&extras=memorare")
        |> v2_response(200)
        |> get_in(["data", "attributes"])

      assert chaplet["extras"] == []
    end

    test "a step carries what the screen shows and how long to wait after it", %{conn: conn} do
      [first | _] = steps = steps(conn, "category=joyful&style=scriptural")

      assert first == %{
               "kind" => "prayer",
               "name" => "sign_of_cross",
               "mystery" => nil,
               "caption" => "The Sign of the Cross",
               "phase" => "opening",
               "decade" => nil,
               "bead" => 0,
               "place" => "cross",
               "pause_ms" => 900
             }

      assert %{
               "name" => "joyful_2_4",
               "caption" => "Scripture · 4 of 10",
               "bead" => 4,
               "decade" => 1
             } =
               Enum.find(steps, &(&1["kind"] == "verse" and &1["name"] == "joyful_2_4"))
    end

    test "an unknown value is an invalid_argument naming the ones it knows", %{conn: conn} do
      for {query, field, names} <- [
            {"category=joyous", "category",
             "joyful, sorrowful, glorious, luminous, seven_sorrows"},
            {"category=joyful&style=sung", "style", "meditation, scriptural, plain"},
            {"category=joyful&extras=angelus", "extras", "holy_father, memorare, st_michael"},
            {"category=joyful&orders=1,6", "orders", "1 to 5"},
            {"category=seven_sorrows&orders=0", "orders", "1 to 7"},
            {"category=joyful&orders=one", "orders", "1 to 5"}
          ] do
        body = conn |> get_v2("/rosary-script?" <> query) |> v2_response(400)

        assert [%{"code" => "invalid_argument", "detail" => detail} | _] = body["errors"],
               query

        # A query parameter has no pointer, so the message names it.
        assert String.starts_with?(detail, field <> " must be"), query
        assert detail =~ names, query
      end
    end

    test "an optional prayer named twice is said once", %{conn: conn} do
      attributes =
        conn
        |> get_v2("/rosary-script?category=joyful&extras=memorare,memorare")
        |> v2_response(200)
        |> get_in(["data", "attributes"])

      assert attributes["extras"] == ["memorare"]
      assert Enum.count(attributes["steps"], &(&1["name"] == "memorare")) == 1
    end

    test "each mystery is prayed at most once, so no Rosary has more decades than its category",
         %{conn: conn} do
      for query <- [
            "category=joyful&orders=1,1",
            "category=joyful&orders=1,2,3,4,5,1",
            "category=seven_sorrows&orders=" <> Enum.join(List.duplicate("1", 4000), ",")
          ] do
        body = conn |> get_v2("/rosary-script?" <> query) |> v2_response(400)

        assert [
                 %{
                   "code" => "invalid_argument",
                   "detail" => "orders must be numbers from 1 to " <> rule
                 }
               ] =
                 body["errors"]

        assert rule =~ "each at most once"
      end

      assert length(steps(conn, "category=seven_sorrows&orders=7,6,5,4,3,2,1")) == 84
    end

    test "a category is required", %{conn: conn} do
      body = conn |> get_v2("/rosary-script") |> v2_response(400)
      assert [%{"code" => "required"} | _] = body["errors"]
    end
  end
end
