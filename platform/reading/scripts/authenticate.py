import argparse
import getpass
import re
from typing import Optional

from playwright.sync_api import Page, expect


class LoginError(Exception):
    pass


def logged_in(page: Page, goto_url: str, home_regex: str, login_regex: str) -> bool:
    """Check if logged in to a site. 'goto_url' should redirect to a home page if logged in, or a login page otherwise.
    'home_regex' and 'login_regex' should match the home page and login page's URL, respectively."""
    page.goto(goto_url)
    page.wait_for_url(re.compile(rf'({home_regex}|{login_regex})'))
    return re.fullmatch(home_regex, page.url) is not None


def zybooks_logged_in(page: Page) -> bool:
    return logged_in(
        page,
        'https://learn.zybooks.com/',
        r'https://learn\.zybooks\.com/library',
        r'https://learn\.zybooks\.com/signin'
    )


def wgu_logged_in(page: Page) -> bool:
    return logged_in(
        page,
        'https://my.wgu.edu/',
        r'https://my\.wgu\.edu/home.*',
        r'https://access\.wgu\.edu/pingfed/as/authorization\.oauth2.*'
    )

def wgu_login(page: Page, username: Optional[str] = None, password: Optional[str] = None) -> None:
    if not wgu_logged_in(page):
        page.get_by_label('Username').fill(username or input('Enter username: '))
        page.get_by_label('Password').fill(password or getpass.getpass('Enter password: '))
        page.get_by_role('button', name='Sign On').click()
        if not wgu_logged_in(page):
            raise LoginError


def zybooks_login(page: Page, course_url: str) -> None:
    """Login to zyBooks via redirect from WGU course page."""
    page.goto(course_url)
    page.goto(page.get_by_role('link', name='GO TO COURSE MATERIAL').get_attribute('href'))
    page.wait_for_url('https://learn.zybooks.com/zybook/**')
    expect(page.locator('.table-of-contents')).to_be_visible()
    if not zybooks_logged_in(page):
        raise LoginError


def setup_parser(parser: argparse.ArgumentParser) -> None:
    parser.add_argument('-u', '--username',
                        help='WGU account username; Can also be provided via interactive input')
    parser.add_argument('-p', '--password',
                        help='WGU account password; Can also be provided via interactive input')
    parser.add_argument('-c', '--course-url', default='https://my.wgu.edu/courses/course/23940006',
                        help='URL of a WGU course which uses zyBooks instructional material')


def authenticate(page: Page, args: argparse.Namespace) -> None:
    if zybooks_logged_in(page):
        return
    wgu_login(page, args.username, args.password)
    zybooks_login(page, args.course_url)