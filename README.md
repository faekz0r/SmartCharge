# SmartCharge

The code in its current state is usable with Tesla cars in Estonia.
It pulls electricity market prices from Elering's API and initiate charging over Tesla API during the the cheapest hours (and of course stops during the expensive ones).
For fully automated use it can be added to some linux boxes crontab for daily runs.

Dependencies: bc, jq, awk


It's mostly written in bash, because when I started this project, that was the language I was most familiar with. I have had thoughts of rewriting it into Python, but am actually amazed at how much can be done with bash (and some additional tools of course).

There's also a frontend for it [here](https://github.com/faekz0r/SmartCharge-frontend), which uses some php and js.

I'm not a professional developer so I am well aware that this could have been done much more eloquently and if you have suggestions for improvements, please push. :)

Also I wrote this purely for myself with no plans to publish it, so it probably has some hardcoded stuffs that are very specific to my setup.

I have tried to clean up the code a bit in the last days, but I'm sure there's tons of more beginner mistakes and just stupid stuffs remaining.

## Running:
1. Get the refresh token for the Tesla API & vehicle id. Google/ChatGPT helps, if you don't know how.
2. Modify private_vars.sh
3. Modify user_vars.sh or use the [frontend](https://github.com/faekz0r/SmartCharge-frontend) for easier access.
4. Run `./main` or put it in crontab
