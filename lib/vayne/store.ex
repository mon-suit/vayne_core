defmodule Vayne.Store do

  @type tasks :: [Vayne.Task.t]
  @type group :: term()

  #Callback
  @callback init([group])           ::  :ok         | {:error, any()}
  @callback save_task(group, tasks) ::  :ok         | {:error, any()}
  @callback get_task(group)         :: {:ok, tasks} | {:error, any()}

end
