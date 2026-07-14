defmodule LumenViaeWeb.Live.Home.TrueDevotion.Index do
  @moduledoc """
  True Devotion to Mary - the Marian teaching of St. Louis de Montfort:
  to Jesus through Mary, true and false devotion, the total consecration,
  and the story of the treatise itself.
  """
  use LumenViaeWeb, :live_view

  embed_templates "_partials/*"

  @false_devotions [
    %{
      name: "The Critical Devotees",
      description:
        "Proud scholars who sit in judgment on devotion to Our Lady, doubting the wonders God has worked through her and looking down on the simple piety of the faithful. They measure everything by their own lights rather than by the mind of the Church."
    },
    %{
      name: "The Scrupulous Devotees",
      description:
        "Souls who fear that honoring the Mother somehow dishonors the Son, and so avoid speaking of Mary or praying to her. St. Louis answers that we never praise Mary except in reference to Jesus, and that she is the surest way to Him."
    },
    %{
      name: "The External Devotees",
      description:
        "Those whose devotion consists entirely in outward practices: many rosaries counted quickly, medals worn, processions joined, but without interior conversion of heart or any effort to amend their lives."
    },
    %{
      name: "The Presumptuous Devotees",
      description:
        "Sinners who hide behind Marian practices while remaining attached to their sins, presuming that Our Lady will save them without repentance. True devotion to Mary never dispenses from the war against sin; it wages it."
    },
    %{
      name: "The Inconstant Devotees",
      description:
        "Those who are devout by fits and starts: fervent for a season, then lax; taking up practices and abandoning them at the first dryness or difficulty. Their devotion depends on feeling rather than on the will."
    },
    %{
      name: "The Hypocritical Devotees",
      description:
        "Those who cloak their sins under the mantle of the Blessed Virgin, practicing devotion in order to appear before men to be what they are not."
    },
    %{
      name: "The Interested Devotees",
      description:
        "Those who have recourse to Our Lady only to win a lawsuit, escape a danger, or be cured of an illness, and who would otherwise forget her entirely. They turn devotion into commerce, seeking only temporal favors."
    }
  ]

  @true_marks [
    %{
      name: "Interior",
      description:
        "It proceeds from the mind and the heart: from a true esteem of Mary's greatness and a genuine love for her, not from routine or display."
    },
    %{
      name: "Tender",
      description:
        "It is full of confidence in Mary, as a child trusts its mother: turning to her simply in every need, in doubt, in temptation, and in fall."
    },
    %{
      name: "Holy",
      description:
        "It leads the soul to avoid sin and to imitate the virtues of the Blessed Virgin: her profound humility, lively faith, blind obedience, continual prayer, universal mortification, divine purity, ardent charity, heroic patience, angelic sweetness, and divine wisdom."
    },
    %{
      name: "Constant",
      description:
        "It confirms the soul in good and does not abandon its practices at the first weariness or trial. The true devotee of Mary is not changeable, fretful, or fainthearted."
    },
    %{
      name: "Disinterested",
      description:
        "It seeks not self but God alone in His holy Mother: serving Mary not for gain or consolation, but because she deserves to be served, and God in her and through her."
    }
  ]

  @prep_phases [
    %{
      id: "preliminary",
      label: "Twelve Preliminary Days",
      days: "Days 1-12",
      focus: "Emptying oneself of the spirit of the world",
      description:
        "The soul renounces the maxims of the world, which are contrary to those of Jesus Christ, examining itself and praying for detachment. Readings are traditionally drawn from the Gospel and the Imitation of Christ."
    },
    %{
      id: "week1",
      label: "First Week",
      days: "Days 13-19",
      focus: "Knowledge of self",
      description:
        "Prayers and meditations for humility: the soul considers its own sins and weakness, asking light to know itself as God knows it. Acts of humility crown the week, for as St. Louis teaches, the foundation of this devotion is a deep knowledge of our own nothingness."
    },
    %{
      id: "week2",
      label: "Second Week",
      days: "Days 20-26",
      focus: "Knowledge of the Blessed Virgin",
      description:
        "The soul studies Mary: her virtues, her greatness, and her office as Mother and Mediatrix, asking Our Lord for the grace to know and love His Mother. The Rosary and the Litany of Loreto accompany the week."
    },
    %{
      id: "week3",
      label: "Third Week",
      days: "Days 27-33",
      focus: "Knowledge of Jesus Christ",
      description:
        "All converges on the end of the devotion: Jesus Christ, Eternal and Incarnate Wisdom. The soul contemplates Who He is, what He has done, and what He deserves, preparing to give itself to Him entirely through Mary."
    },
    %{
      id: "consecration",
      label: "The Day of Consecration",
      days: "Day 34",
      focus: "The total consecration",
      description:
        "On a feast of Our Lady, after Confession and Holy Communion, the soul pronounces the Act of Consecration, giving itself wholly to Jesus through the hands of Mary. The consecration is traditionally renewed each year on the same feast."
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "True Devotion to Mary")
      |> assign(
        meta_description:
          "The Marian teaching of St. Louis de Montfort: to Jesus through Mary, the marks of true and false devotion, the total consecration with its 33-day preparation, and the remarkable story of the treatise itself."
      )
      |> assign(false_devotions: @false_devotions, true_marks: @true_marks)
      |> assign(devotion_tab: "true")
      |> assign(prep_phases: @prep_phases, prep_phase: "preliminary")

    {:ok, socket}
  end

  @impl true
  def handle_event("select-devotion-tab", %{"tab" => tab}, socket)
      when tab in ["true", "false"] do
    {:noreply, assign(socket, :devotion_tab, tab)}
  end

  def handle_event("select-devotion-tab", _params, socket), do: {:noreply, socket}

  def handle_event("select-prep-phase", %{"phase" => phase}, socket) do
    valid? = Enum.any?(@prep_phases, &(&1.id == phase))
    {:noreply, if(valid?, do: assign(socket, :prep_phase, phase), else: socket)}
  end

  @doc """
  Returns the currently selected preparation phase map.
  """
  def current_phase(phases, phase_id) do
    Enum.find(phases, &(&1.id == phase_id)) || hd(phases)
  end
end
