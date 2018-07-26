
Logger.remove_backend(:console)

"#{Path.dirname(__ENV__.file)}/support/*"
|> Path.wildcard
|> Enum.filter(&!File.dir?(&1))
|> Enum.each(&Code.require_file/1)

ExUnit.start()
