# `DOORMAN`

 a Procfile runner / foreman clone for BASH
 
## usage:

```console
  $ doorman.sh [-h❘--help]
  $ doorman.sh [-v❘--version]
  $ doorman.sh [-p PROCFILE] [[-e ENVFILE] ꓺ] [-d PATH] [-f❘-w] [-r [MAXTRIES]] [-t [SECONDS]]
```

## available options:

- `-p`, `--procfile=PROCFILE`
  Specify an alternate _Procfile_ to use instead of '`$PATH/Procfil`e'.

- `-e`, `--env=ENVFILE`
  Specify additional _DotEnv_ ('`.env`') files to load after '`$PATH/.env`'.

- `-d`, `--directory=PATH`
  Specify an alternate directory to use as the root directory, which will be used as the directory where commands in the _Procfile_ will be executed, and where '`.env`' files will be searched for.  
  The default root directory is the directory containing the Procfile.

- `-f`, `--fail-one`
Shut down when _ANY_ process exits, terminating remaining processes.

- `-w`, `--wait-all`
  Shut down only after _ALL_ processes have exited. This is the default mode.

- `-r`, `--restart[=MAXTRIES]`
  Restart processes which have exited, with an optional limit on the maximum tries.  
  When the argument is present with the optional `MAXTRIES` parameter omitted, the value defaults to **0**, which means no restart limit.  
  Otherwise _Doorman_ lets processes fail after running them `MAXTRIES` times.
  Without the `--restart` argument, each process runs only once.

- `-t`, `--timeout[=SECONDS]`
  Set a shutdown timeout in seconds each process is given to terminate before being sent a `KILL` signal in the event of _Doorman_ shutting down.  
  When the argument is present with the optional `SECONDS` parameter omitted, the timeout defaults to **3** seconds.
  Without the `--timeout` argument, processes are `KILL`ed immediately.

## Contributing

Contributions, issues and feature requests are welcome.

Feel free to check [issues page][issues], if you want to contribute.

[issues]: https://github.org/razielanarki/doorman/issues

## Author

### Raziel Anarki

- GitHub:   [razielanarki][repos] 
- Facebook: [facebook.com/razielanarki][social]
- Email:    [razielanarki-AT-semmi-DOT-se][email]

[repos]:  https://github.org/razielanarki
[social]: https://www.facebook.com/razielanarki
[email]:  mailto:razielanarki-AT-semmi-DOT-se

## License

Copyright © 2020-2023 Raziel Anarki

This project is licensed under the [MIT license][license].

[license]: LICENSE.md
