defmodule LumenViaeWeb.Live.Home.Methods.Index do
  @moduledoc """
  How to Pray the Rosary - a step-by-step interactive guide with the
  traditional prayers, followed by the five methods of St. Louis de Montfort
  and the fifteen promises of the Rosary.
  """
  use LumenViaeWeb, :live_view

  embed_templates "_partials/*"

  @steps [
    %{
      id: 1,
      title: "The Sign of the Cross and the Creed",
      beads: ["crucifix"],
      instruction:
        "Take the crucifix in hand, make the Sign of the Cross, and pray the Apostles' Creed.",
      prayers: [
        %{
          name: "The Sign of the Cross",
          text: "In the name of the Father, and of the Son, and of the Holy Ghost. Amen."
        },
        %{
          name: "The Apostles' Creed",
          text:
            "I believe in God, the Father Almighty, Creator of heaven and earth; and in Jesus Christ, His only Son, our Lord; Who was conceived by the Holy Ghost, born of the Virgin Mary, suffered under Pontius Pilate, was crucified, died, and was buried. He descended into hell; the third day He arose again from the dead; He ascended into heaven, and sitteth at the right hand of God, the Father Almighty; from thence He shall come to judge the living and the dead. I believe in the Holy Ghost, the Holy Catholic Church, the communion of Saints, the forgiveness of sins, the resurrection of the body, and life everlasting. Amen."
        }
      ],
      note: nil
    },
    %{
      id: 2,
      title: "The Our Father",
      beads: ["of1"],
      instruction: "On the first large bead, pray the Our Father.",
      prayers: [
        %{
          name: "The Our Father",
          text:
            "Our Father, Who art in heaven, hallowed be Thy name; Thy kingdom come; Thy will be done on earth as it is in heaven. Give us this day our daily bread; and forgive us our trespasses, as we forgive those who trespass against us; and lead us not into temptation, but deliver us from evil. Amen."
        }
      ],
      note: nil
    },
    %{
      id: 3,
      title: "Three Hail Marys",
      beads: ["hm3"],
      instruction:
        "On the three small beads, pray three Hail Marys for an increase of faith, hope, and charity.",
      prayers: [
        %{
          name: "The Hail Mary",
          text:
            "Hail Mary, full of grace, the Lord is with thee; blessed art thou amongst women, and blessed is the fruit of thy womb, Jesus. Holy Mary, Mother of God, pray for us sinners, now and at the hour of our death. Amen."
        }
      ],
      note:
        "St. Louis de Montfort offers these three Hail Marys to the Most Holy Trinity in thanksgiving for all the graces given to Mary, and given to us through her intercession."
    },
    %{
      id: 4,
      title: "The Glory Be",
      beads: ["of2"],
      instruction: "On the next large bead, pray the Glory Be to the Father.",
      prayers: [
        %{
          name: "The Glory Be (Gloria Patri)",
          text:
            "Glory be to the Father, and to the Son, and to the Holy Ghost. As it was in the beginning, is now, and ever shall be, world without end. Amen."
        }
      ],
      note: nil
    },
    %{
      id: 5,
      title: "Announce the First Mystery",
      beads: ["medal"],
      instruction:
        "At the centerpiece medal, announce the first mystery of the day, pause to place yourself in the scene, and pray the Our Father.",
      prayers: [
        %{
          name: "The Our Father",
          text:
            "Our Father, Who art in heaven, hallowed be Thy name; Thy kingdom come; Thy will be done on earth as it is in heaven. Give us this day our daily bread; and forgive us our trespasses, as we forgive those who trespass against us; and lead us not into temptation, but deliver us from evil. Amen."
        }
      ],
      note:
        "Traditional schedule: Joyful on Monday and Thursday, Sorrowful on Tuesday and Friday, Glorious on Wednesday, Saturday, and Sunday (Joyful on the Sundays of Advent, Sorrowful on the Sundays of Lent)."
    },
    %{
      id: 6,
      title: "Pray the Decade",
      beads: ["decade1"],
      instruction:
        "On the ten small beads, pray ten Hail Marys while meditating on the mystery. The meditation, not the counting, is the soul of the Rosary.",
      prayers: [
        %{
          name: "The Hail Mary",
          text:
            "Hail Mary, full of grace, the Lord is with thee; blessed art thou amongst women, and blessed is the fruit of thy womb, Jesus. Holy Mary, Mother of God, pray for us sinners, now and at the hour of our death. Amen."
        }
      ],
      note:
        "To keep the mystery before your mind, St. Louis de Montfort suggests adding a phrase after the name of Jesus in each Hail Mary, such as \"Jesus, conceived by the Holy Ghost\" during the Annunciation."
    },
    %{
      id: 7,
      title: "Close the Decade",
      beads: ["sep1"],
      instruction:
        "After the tenth Hail Mary, pray the Glory Be. It is customary to add the Fatima Prayer. Then, on the large bead, announce the next mystery and pray the Our Father.",
      prayers: [
        %{
          name: "The Glory Be (Gloria Patri)",
          text:
            "Glory be to the Father, and to the Son, and to the Holy Ghost. As it was in the beginning, is now, and ever shall be, world without end. Amen."
        },
        %{
          name: "The Fatima Prayer",
          text:
            "O my Jesus, forgive us our sins, save us from the fires of hell; lead all souls to Heaven, especially those who have most need of Thy mercy. Amen."
        }
      ],
      note:
        "Our Lady asked for the Fatima Prayer during the apparition of July 13, 1917. It is a pious custom added after each decade, not part of the ancient form of the Rosary."
    },
    %{
      id: 8,
      title: "Continue the Remaining Decades",
      beads: ["rest"],
      instruction:
        "Continue around the beads in the same way for the remaining four decades: announce the mystery, pray the Our Father, ten Hail Marys, the Glory Be, and the Fatima Prayer.",
      prayers: [],
      note:
        "Five decades form a chaplet, one third of the traditional fifteen-mystery Rosary. The saints often prayed all fifteen decades in a day."
    },
    %{
      id: 9,
      title: "The Hail Holy Queen",
      beads: ["medal"],
      instruction:
        "Having completed the five decades, return to the medal and pray the Hail Holy Queen and the closing collect.",
      prayers: [
        %{
          name: "The Hail Holy Queen (Salve Regina)",
          text:
            "Hail, Holy Queen, Mother of Mercy, our life, our sweetness, and our hope. To thee do we cry, poor banished children of Eve. To thee do we send up our sighs, mourning and weeping in this valley of tears. Turn then, most gracious Advocate, thine eyes of mercy toward us, and after this our exile, show unto us the blessed fruit of thy womb, Jesus. O clement, O loving, O sweet Virgin Mary. V. Pray for us, O holy Mother of God. R. That we may be made worthy of the promises of Christ."
        },
        %{
          name: "The Closing Collect",
          text:
            "Let us pray. O God, Whose only-begotten Son, by His life, death, and resurrection, hath purchased for us the rewards of eternal life: grant, we beseech Thee, that, meditating upon these mysteries of the most holy Rosary of the Blessed Virgin Mary, we may imitate what they contain and obtain what they promise. Through the same Christ our Lord. Amen."
        }
      ],
      note:
        "Many also add the Litany of Loreto or the Prayer to St. Michael, especially when the Rosary is prayed in common."
    },
    %{
      id: 10,
      title: "The Final Sign of the Cross",
      beads: ["crucifix"],
      instruction:
        "Conclude with the Sign of the Cross. It is a pious custom to kiss the crucifix in token of love for Our Lord.",
      prayers: [
        %{
          name: "The Sign of the Cross",
          text: "In the name of the Father, and of the Son, and of the Holy Ghost. Amen."
        }
      ],
      note: nil
    }
  ]

  @method_one %{
    "joyful" => %{
      name: "The Joyful Mysteries",
      decades: [
        %{
          number: "First Decade",
          mystery: "The Annunciation",
          offering:
            "We offer Thee, O Lord Jesus, this first decade in honor of Thine Incarnation, and we ask of Thee, through this mystery and through the intercession of Thy most Holy Mother, a profound humility.",
          grace:
            "Grace of the mystery of the Incarnation, come down into my soul and make it truly humble."
        },
        %{
          number: "Second Decade",
          mystery: "The Visitation",
          offering:
            "We offer Thee, O Lord Jesus, this second decade in honor of the Visitation of Thy Holy Mother to her cousin Saint Elizabeth, and we ask of Thee, through this mystery and through Mary's intercession, a perfect charity towards our neighbor.",
          grace:
            "Grace of the mystery of the Visitation, come down into my soul and make it really charitable."
        },
        %{
          number: "Third Decade",
          mystery: "The Nativity",
          offering:
            "We offer Thee, O Child Jesus, this third decade in honor of Thy Blessed Nativity, and we ask of Thee, through this mystery and through the intercession of Thy Blessed Mother, detachment from the things of this world, love of poverty and love of the poor.",
          grace:
            "Grace of the mystery of the Nativity, come down into my soul and make me truly poor in spirit."
        },
        %{
          number: "Fourth Decade",
          mystery: "The Presentation",
          offering:
            "We offer Thee, O Lord Jesus, this fourth decade in honor of Thy Presentation in the temple by the hands of Mary, and we ask of Thee, through this mystery and through the intercession of Thy Blessed Mother, the gift of wisdom and purity of heart and body.",
          grace:
            "Grace of the mystery of the Presentation, come down into my soul and make me truly wise and truly pure."
        },
        %{
          number: "Fifth Decade",
          mystery: "The Finding in the Temple",
          offering:
            "We offer Thee, O Lord Jesus, this fifth decade in honor of Mary's finding of Thee in the Temple, and we ask of Thee, through this mystery and through the intercession of Thy Blessed Mother, our own conversion and the conversion of all sinners.",
          grace:
            "Grace of the mystery of the Finding of the Child Jesus in the Temple, come down into my soul and truly convert me."
        }
      ]
    },
    "sorrowful" => %{
      name: "The Sorrowful Mysteries",
      decades: [
        %{
          number: "Sixth Decade",
          mystery: "The Agony in the Garden",
          offering:
            "We offer Thee, O Lord Jesus, this sixth decade in honor of Thy mortal Agony in the Garden of Olives, and we ask of Thee, through this mystery and through the intercession of Thy Holy Mother, perfect sorrow for our sins and perfect conformity to Thy holy will.",
          grace:
            "Grace of the Agony of Jesus, come down into my soul and make me truly contrite and perfectly obedient to the will of God."
        },
        %{
          number: "Seventh Decade",
          mystery: "The Scourging at the Pillar",
          offering:
            "We offer Thee, O Lord Jesus, this seventh decade in honor of Thy cruel Scourging, and we ask of Thee, through this mystery and through the intercession of Thy Holy Mother, the grace to mortify our senses.",
          grace:
            "Grace of the mystery of the Scourging of Jesus, come down into my soul and make me truly mortified."
        },
        %{
          number: "Eighth Decade",
          mystery: "The Crowning with Thorns",
          offering:
            "We offer Thee, O Lord Jesus, this eighth decade in honor of Thy being crowned with thorns, and we ask of Thee, through this mystery and through the intercession of Thy Holy Mother, a deep contempt of the world.",
          grace:
            "Grace of the mystery of the Crowning with Thorns, come down into my soul and detach my heart from the world."
        },
        %{
          number: "Ninth Decade",
          mystery: "The Carrying of the Cross",
          offering:
            "We offer Thee, O Lord Jesus, this ninth decade in honor of Thy Carrying of the Cross, and we ask of Thee, through this mystery and through the intercession of Thy Holy Mother, great patience in bearing our cross after Thee all the days of our life.",
          grace:
            "Grace of the mystery of the Carrying of the Cross, come down into my soul and make me truly patient."
        },
        %{
          number: "Tenth Decade",
          mystery: "The Crucifixion",
          offering:
            "We offer Thee, O Lord Jesus, this tenth decade in honor of Thy Crucifixion on Mount Calvary, and we ask of Thee, through this mystery and through the intercession of Thy Holy Mother, a great horror of sin, a love of the Cross, and the grace of a holy death for us and for those who are now in their last agony.",
          grace:
            "Grace of the mystery of the Death and Passion of Our Lord, come down into my soul and make me truly holy."
        }
      ]
    },
    "glorious" => %{
      name: "The Glorious Mysteries",
      decades: [
        %{
          number: "Eleventh Decade",
          mystery: "The Resurrection",
          offering:
            "We offer Thee, O Lord Jesus, this eleventh decade in honor of Thy triumphant Resurrection, and we ask of Thee, through this mystery and through the intercession of Thy Holy Mother, a lively faith.",
          grace:
            "Grace of the mystery of the Resurrection, come down into my soul and make me truly faithful."
        },
        %{
          number: "Twelfth Decade",
          mystery: "The Ascension",
          offering:
            "We offer Thee, O Lord Jesus, this twelfth decade in honor of Thy glorious Ascension, and we ask of Thee, through this mystery and through the intercession of Thy Holy Mother, a firm hope and a great longing for heaven.",
          grace:
            "Grace of the mystery of the Ascension of Our Lord, come down into my soul and prepare me for heaven."
        },
        %{
          number: "Thirteenth Decade",
          mystery: "The Descent of the Holy Ghost",
          offering:
            "We offer Thee, O Holy Ghost, this thirteenth decade in honor of the mystery of Pentecost, and we ask of Thee, through this mystery and through the intercession of Mary, Thy most holy Spouse, holy wisdom, that we may know, relish, and practice Thy truth, and share it with all men.",
          grace:
            "Grace of Pentecost, come down into my soul and make me truly wise in the eyes of God."
        },
        %{
          number: "Fourteenth Decade",
          mystery: "The Assumption",
          offering:
            "We offer Thee, O Lord Jesus, this fourteenth decade in honor of the Immaculate Conception of Thy Holy Mother and her Assumption, body and soul, into heaven, and we ask of Thee, through these two mysteries and through her intercession, a true devotion to so good a Mother, that we may live a good life and die a happy death.",
          grace:
            "Grace of the mysteries of the Immaculate Conception and the Assumption of Mary, come down into my soul and make me truly devoted to her."
        },
        %{
          number: "Fifteenth Decade",
          mystery: "The Coronation of Our Lady",
          offering:
            "We offer Thee, O Lord Jesus, this fifteenth and last decade in honor of the Coronation in glory of Thy Holy Mother in heaven, and we ask of Thee, through this mystery and through her intercession, perseverance and increase in virtue up to the moment of our death, and thereafter the eternal crown prepared for us. We ask the same grace for all the just and for all our benefactors.",
          grace:
            "Grace of the mystery of the Coronation of Mary, come down into my soul and lead me to persevere unto the crown of glory."
        }
      ]
    }
  }

  @method_set_order ["joyful", "sorrowful", "glorious"]

  @promises [
    "Whosoever shall faithfully serve me by the recitation of the Rosary shall receive signal graces.",
    "I promise my special protection and the greatest graces to all those who shall recite the Rosary.",
    "The Rosary shall be a powerful armor against hell; it will destroy vice, decrease sin, and defeat heresies.",
    "It will cause virtue and good works to flourish; it will obtain for souls the abundant mercy of God; it will withdraw the hearts of men from the love of the world and its vanities, and will lift them to the desire of eternal things.",
    "The soul which recommends itself to me by the recitation of the Rosary shall not perish.",
    "Whosoever shall recite the Rosary devoutly, applying himself to the consideration of its sacred mysteries, shall never be conquered by misfortune, shall not perish by an unprovided death, and shall remain in the grace of God, becoming worthy of eternal life.",
    "Whosoever shall have a true devotion for the Rosary shall not die without the sacraments of the Church.",
    "Those who are faithful to recite the Rosary shall have, during their life and at their death, the light of God and the plenitude of His graces, and shall share in the merits of the blessed in paradise.",
    "I shall deliver from purgatory those who have been devoted to the Rosary.",
    "The faithful children of the Rosary shall merit a high degree of glory in heaven.",
    "You shall obtain all you ask of me by the recitation of the Rosary.",
    "All those who propagate the holy Rosary shall be aided by me in their necessities.",
    "I have obtained from my Divine Son that all the advocates of the Rosary shall have for intercessors the entire celestial court during their life and at the hour of death.",
    "All who recite the Rosary are my sons and daughters, and brothers and sisters of my only Son, Jesus Christ.",
    "Devotion to my Rosary is a great sign of predestination."
  ]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "How to Pray the Rosary")
      |> assign(
        meta_description:
          "A step-by-step guide to praying the Holy Rosary, with the traditional prayers, an interactive bead-by-bead walkthrough, the five methods of St. Louis de Montfort, and the fifteen promises of the Rosary."
      )
      |> assign(steps: @steps, selected_step: 1)
      |> assign(method_one: @method_one, method_set: "joyful")
      |> assign(promises: @promises)
      |> assign(loop_beads: loop_beads())

    {:ok, socket}
  end

  @impl true
  def handle_event("select-step", %{"step" => step}, socket) do
    {:noreply, assign(socket, :selected_step, clamp_step(step))}
  end

  def handle_event("next-step", _params, socket) do
    {:noreply, assign(socket, :selected_step, clamp_step(socket.assigns.selected_step + 1))}
  end

  def handle_event("prev-step", _params, socket) do
    {:noreply, assign(socket, :selected_step, clamp_step(socket.assigns.selected_step - 1))}
  end

  def handle_event("select-method-set", %{"set" => set}, socket) when set in @method_set_order do
    {:noreply, assign(socket, :method_set, set)}
  end

  def handle_event("select-method-set", _params, socket), do: {:noreply, socket}

  @doc """
  Returns the currently selected step map.
  """
  def current_step(steps, selected_step) do
    Enum.find(steps, &(&1.id == selected_step)) || hd(steps)
  end

  @doc """
  True when the given bead group belongs to the selected step.
  """
  def bead_active?(steps, selected_step, bead_key) do
    bead_key in current_step(steps, selected_step).beads
  end

  def method_set_order, do: @method_set_order

  @doc """
  Maps a loop bead group to the how-to step it teaches.
  """
  def step_for_bead("decade1"), do: 6
  def step_for_bead("sep1"), do: 7
  def step_for_bead("rest"), do: 8

  defp clamp_step(step) when is_binary(step), do: step |> String.to_integer() |> clamp_step()
  defp clamp_step(step) when step < 1, do: 1
  defp clamp_step(step) when step > length(@steps), do: length(@steps)
  defp clamp_step(step), do: step

  # Positions for the beads of the rosary loop, distributed on a circle.
  # Slot 0 (the bottom of the loop) is reserved for the centerpiece medal,
  # which is drawn separately in the template. The first decade proceeds
  # clockwise (to the right of the medal), so the angle decreases per slot.
  defp loop_beads do
    for slot <- 1..54 do
      angle_rad = (90 - slot * 360 / 55) * :math.pi() / 180

      %{
        x: Float.round(210 + 148 * :math.cos(angle_rad), 2),
        y: Float.round(185 + 148 * :math.sin(angle_rad), 2),
        key: loop_key(slot),
        r: if(slot in [11, 22, 33, 44], do: 8.5, else: 6)
      }
    end
  end

  defp loop_key(slot) when slot in 1..10, do: "decade1"
  defp loop_key(11), do: "sep1"
  defp loop_key(_slot), do: "rest"
end
