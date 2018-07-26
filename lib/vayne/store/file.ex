defmodule Vayne.Store.File do

  @default_dir ".record"
  def group_dir(group), do: File.cwd! |> Path.join(@default_dir) |> Path.join(to_string(group))

  def init(groups) do
    Enum.each(groups, fn g -> g |> group_dir() |>  File.mkdir_p!() end)
    :ok
  end

  @task_file "task"
  @tmp_file ".tmp_task"
  @keep 5
  def save_task(group, tasks) do
    dir = group_dir(group)
    binary = :erlang.term_to_binary(tasks, [:compressed])
    with tmp_file  =  Path.join(dir, @tmp_file),
         task_file =  Path.join(dir, @task_file),
         :ok       <- File.write(tmp_file, binary),
         _         =  Enum.each(@keep..1, fn i -> File.rename("#{task_file}.#{i}", "#{task_file}.#{i+1}")  end),
         _         =  File.rename(task_file, "#{task_file}.1"),
         _         =  File.rm("#{task_file}.#{@keep+1}"),
         :ok       <- File.rename(tmp_file, task_file)
    do
      :ok
    else
      error = {:error, _} -> error
      error -> {:error, error}
    end

  end

  def get_task(group) do
    task_file = group |> group_dir() |> Path.join(@task_file)

    with {:ok, str} <- File.read(task_file),
             tasks  <- :erlang.binary_to_term(str)
    do
      {:ok, tasks}
    else
      error = {:error, _} -> error
      error -> {:error, error}
    end
  end

end
