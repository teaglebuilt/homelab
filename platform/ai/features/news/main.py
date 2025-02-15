import sys
from news.crew import NewsCrew


def run():
    inputs = {
        'topic': 'AI Agents'
    }
    NewsCrew().crew().kickoff(inputs=inputs)
