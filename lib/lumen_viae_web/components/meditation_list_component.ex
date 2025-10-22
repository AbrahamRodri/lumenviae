defmodule LumenViaeWeb.MeditationListComponent do
  use Phoenix.Component

  attr :meditations, :list, required: true
  attr :expanded_meditation_id, :integer, default: nil
  attr :editing_meditation_id, :integer, default: nil
  attr :edit_form, :map, default: nil
  attr :mysteries, :list, required: true

  def meditation_list(assigns) do
    ~H"""
    <div class="bg-white border-l-4 border-gold p-8">
      <h3 class="font-cinzel text-2xl text-navy mb-6">All Meditations</h3>
      <%= if @meditations == [] do %>
        <p class="font-crimson text-gray-600">
          No meditations yet. Create some using the form above!
        </p>
      <% else %>
        <div class="space-y-4">
          <%= for meditation <- @meditations do %>
            <div class="border border-gray-200 rounded-lg overflow-hidden">
              <button
                phx-click="toggle_meditation"
                phx-value-id={meditation.id}
                class="w-full p-4 text-left hover:bg-cream transition-colors flex justify-between items-center"
              >
                <div class="flex-1">
                  <h4 class="font-cinzel text-lg text-navy">
                    {meditation.mystery.name}
                    {if meditation.title, do: " - #{meditation.title}"}
                  </h4>
                  <div class="flex gap-4 mt-1">
                    <%= if meditation.author do %>
                      <p class="font-crimson text-sm text-gray-500">by {meditation.author}</p>
                    <% end %>
                    <%= if meditation.source do %>
                      <p class="font-crimson text-sm text-gray-400 italic">
                        from {meditation.source}
                      </p>
                    <% end %>
                  </div>
                </div>
                <div class="flex items-center gap-3">
                  <span class="font-crimson text-xs text-gray-400">
                    ID: {meditation.id}
                  </span>
                  <span class="text-navy">
                    <%= if @expanded_meditation_id == meditation.id do %>
                      ▼
                    <% else %>
                      ▶
                    <% end %>
                  </span>
                </div>
              </button>

              <%= if @expanded_meditation_id == meditation.id do %>
                <div class="p-4 bg-cream border-t border-gray-200">
                  <%= if @editing_meditation_id == meditation.id && @edit_form do %>
                    <!-- Edit Form -->
                    <Phoenix.Component.form
                      for={@edit_form}
                      phx-submit="update_meditation"
                      class="space-y-4"
                    >
                      <input type="hidden" name="meditation_id" value={meditation.id} />

                      <div>
                        <label class="font-crimson text-navy font-semibold block mb-2">Mystery</label>
                        <select
                          name="mystery_id"
                          required
                          class="w-full p-3 border border-gray-300 rounded font-crimson text-black"
                        >
                          <%= for mystery <- @mysteries do %>
                            <option
                              value={mystery.id}
                              selected={to_string(mystery.id) == @edit_form.params["mystery_id"]}
                            >
                              {mystery.name} ({String.capitalize(mystery.category)})
                            </option>
                          <% end %>
                        </select>
                      </div>

                      <div>
                        <label class="font-crimson text-navy font-semibold block mb-2">
                          Title (Optional)
                        </label>
                        <input
                          type="text"
                          name="title"
                          value={@edit_form.params["title"]}
                          class="w-full p-3 border border-gray-300 rounded font-crimson text-black"
                        />
                      </div>

                      <div>
                        <label class="font-crimson text-navy font-semibold block mb-2">Content</label>
                        <textarea
                          name="content"
                          required
                          rows="12"
                          class="w-full p-3 border border-gray-300 rounded font-crimson text-black"
                        ><%= @edit_form.params["content"] %></textarea>
                      </div>

                      <div class="grid md:grid-cols-2 gap-4">
                        <div>
                          <label class="font-crimson text-navy font-semibold block mb-2">
                            Author
                          </label>
                          <input
                            type="text"
                            name="author"
                            value={@edit_form.params["author"]}
                            class="w-full p-3 border border-gray-300 rounded font-crimson text-black"
                          />
                        </div>
                        <div>
                          <label class="font-crimson text-navy font-semibold block mb-2">
                            Source (Optional)
                          </label>
                          <input
                            type="text"
                            name="source"
                            value={@edit_form.params["source"]}
                            class="w-full p-3 border border-gray-300 rounded font-crimson text-black"
                          />
                        </div>
                      </div>

                      <div class="flex gap-3">
                        <button
                          type="submit"
                          class="bg-navy text-white px-6 py-2 rounded hover:bg-gold hover:text-navy transition-colors font-crimson"
                        >
                          Save Changes
                        </button>
                        <button
                          type="button"
                          phx-click="cancel_edit"
                          class="bg-gray-500 text-white px-6 py-2 rounded hover:bg-gray-600 transition-colors font-crimson"
                        >
                          Cancel
                        </button>
                      </div>
                    </Phoenix.Component.form>
                  <% else %>
                    <!-- View Mode -->
                    <div class="mb-3">
                      <span class="font-crimson text-sm font-semibold text-navy">
                        Mystery Category:
                      </span>
                      <span class="font-crimson text-sm text-gray-700 ml-2">
                        {String.capitalize(meditation.mystery.category)}
                      </span>
                    </div>
                    <div class="mb-3">
                      <h5 class="font-crimson text-sm font-semibold text-navy mb-2">
                        Meditation Content:
                      </h5>
                      <div class="font-crimson text-gray-800 whitespace-pre-wrap bg-white p-4 rounded border border-gray-200 max-h-96 overflow-y-auto">
                        {meditation.content}
                      </div>
                    </div>
                    <div class="flex gap-3 mt-4">
                      <button
                        phx-click="edit_meditation"
                        phx-value-id={meditation.id}
                        class="bg-navy text-white px-4 py-2 rounded hover:bg-gold hover:text-navy transition-colors font-crimson text-sm"
                      >
                        Edit
                      </button>
                      <button
                        phx-click="delete_meditation"
                        phx-value-id={meditation.id}
                        data-confirm="Are you sure you want to delete this meditation?"
                        class="bg-red-600 text-white px-4 py-2 rounded hover:bg-red-700 transition-colors font-crimson text-sm"
                      >
                        Delete
                      </button>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
