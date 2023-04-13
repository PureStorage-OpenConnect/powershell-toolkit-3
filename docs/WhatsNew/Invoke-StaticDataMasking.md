# What's new in Invoke-Pfa2StaticDataMasking

- Add support for standard parameters `-Verbose`, `-Confirm`, and `-WhatIf`
- Add optional SqlCredential parameter
- Add optional table name list
- Add dbatools consistence

## Table list

Optional `-Table` parameter specifies a list of table names to be processed. When omitted, all tables are subject to update.

## Consistence with dbatools

The `-SqlInstance` parameter can be not only an instance name but anything accepted by `Invoke-DbaQuery` as `-SqlInstance`.
