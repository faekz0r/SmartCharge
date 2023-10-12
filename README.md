# SmartCharge

The code in its current form is designed to work with Tesla cars in Estonia. It fetches electricity market prices from Elering's API and controls charging through the Tesla API to take advantage of the cheapest hours. Conversely, it stops charging during more expensive times.

For fully automated operation, the script can be added to a Linux machine's crontab for daily execution.

## Dependencies:
* bc
* jq
* awk


It's mostly written in Bash, because it was the language I was most familiar with when I started this project. Although I have considered rewriting it in Python, I'm amazed at how much can be accomplished with Bash, especially when complemented by other tools.

There's also a frontend for it [here](https://github.com/faekz0r/SmartCharge-frontend), which uses some php and js.

## Disclaimer / background
This project was started after I was fed up with a public solution, that was bugging out too often - waking up my Tesla when not needed & not charging at the correct times etc. So I took the matter in my own hands. :)

I'm not a professional developer so I am well aware that this could have been done much more eloquently and quicker and if you have suggestions for improvements, please push. :)

Also I wrote this purely for myself with no plans to publish it, so it may contain hardcoded variables specific to my setup.

I have tried to clean up the code a bit in the last days, but I'm sure there's tons of more beginner mistakes and just stupid stuffs remaining.

## Running:
1. Obtain the refresh token & vehicle id for the Tesla API. Google/ChatGPT helps, if you're unfamiliar with this step.
2. Edit private_vars.sh to include your specific information.
3. Modify user_vars.sh or use the [frontend](https://github.com/faekz0r/SmartCharge-frontend) for easier access.
4. Run `./main` or put it in crontab
