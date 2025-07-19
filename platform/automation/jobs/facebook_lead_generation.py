
from crewai import Agent
# import our tools
from browserbase import browserbase


search_agent = Agent(
    role="",
    goal="Search Facebook",
    backstory="I am an insurance agent looking for leads on facebook.",
    tools=[browserbase],
    allow_delegation=False,
)

summarize_agent = Agent(
    role="Summarize",
    goal="Summarize content",
    backstory="I am an agent that can summarize text.",
    allow_delegation=False,
)
