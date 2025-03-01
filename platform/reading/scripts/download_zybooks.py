#!/usr/bin/env python3
import argparse
import logging
import re
import sys
from pathlib import Path
from typing import Optional

from playwright.sync_api import ElementHandle, Page, expect, sync_playwright

import authenticate

log_levels = {
    0: logging.ERROR,
    1: logging.WARN,
    2: logging.INFO,
    3: logging.DEBUG,
}


def slice_arg(arg: str) -> slice:
    return slice(*(int(x) if x else None for x in arg.split(':')))


def path_arg(arg: str) -> Path:
    return Path(arg).expanduser()


def await_stable_html(page: Page, element: ElementHandle, poll_delay: int = 1000) -> None:
    """Ensure that a page element has reached a stable state
    by confirming its inner HTML is identical after poll_delay milliseconds."""
    html_previous = ''
    while True:
        html_current = element.inner_html()
        if html_current == html_previous:
            break
        logging.debug('Unstable!')
        html_previous = html_current
        page.wait_for_timeout(poll_delay)
    logging.debug('Stable.')


def sanitize_filename(name: str) -> str:
    name = re.sub(r'[<>"\\|?*]', '', name)
    name = re.sub(r'\s?:\s?', ' - ', name)
    return re.sub(r'\s?/\s?', ' and ', name)


def print_chapter(page: Page, url: str, file: Path) -> None:
    page.goto(url)
    # Becomes actionable when we have recieved all data, but before we have rendered everything
    page.get_by_role('button', name='Print').first.click(trial=True, timeout=600000)
    for section in page.query_selector('.print-this').query_selector_all('.zybook-section'):
        logging.debug(section.query_selector('.zybook-section-title').text_content().strip())
        # Wait until we have finished rendering the section's content
        await_stable_html(page, section)
    page.pdf(path=file)


def print_zybook(page: Page, zybook_url: str, output_dir: Path = Path('.'),
                 chapters_slice: Optional[slice] = None) -> None:
    page.goto(zybook_url)
    expect(page.locator('.table-of-contents')).to_be_visible()

    chapters = [
        x.query_selector('.chapter-title').text_content().strip()
        for x in page.locator('ul > li').element_handles()
    ]
    logging.debug(f'Chapters: {chapters}')
    base_url = page.url.rstrip('/')

    # ElementHandle.inner_html may exceed the default timeout of 30s for large chapters.
    # This method does not accept a 'timeout' parameter, so we must change the default timeout here.
    page.set_default_timeout(120000)

    sliced_chapters = chapters[chapters_slice] if chapters_slice else chapters
    for i in sliced_chapters:
        chapter_url = f'{base_url}/chapter/{chapters.index(i)+1}/print'
        file_name = output_dir.joinpath(sanitize_filename(i) + '.pdf')
        logging.debug(chapter_url)
        print_chapter(page, chapter_url, file_name)
        logging.debug(file_name)


def dl(page: Page, args: argparse.Namespace) -> None:
    print_zybook(
        page,
        args.zybook_url,
        args.output_dir,
        args.chapters_slice
    )


def main() -> None:
    parser = argparse.ArgumentParser(description='Downloads zyBooks e-textbook chapters as PDFs')
    parser.add_argument('-a', '--auth-file', type=path_arg, default='~/.download-zybooks-state.json',
                        help='File storing authenticated session state')
    parser.add_argument('--no-headless', dest='headless', action='store_false',
                        help='Do not run browser in headless mode')
    parser.add_argument('-v', '--verbose', dest='verbosity', action='count', default=0,
                        help='Logging verbosity (0-3 occurences); ERROR=0, WARN=1, INFO=2, DEBUG=3')
    subparsers = parser.add_subparsers(required=True)

    parser_auth = subparsers.add_parser('auth', help='Authenticate to zyBooks and save authenticated state to file')
    authenticate.setup_parser(parser_auth)
    parser_auth.set_defaults(func=authenticate.authenticate)

    parser_dl = subparsers.add_parser('dl', help='Download a zyBooks textbook')
    parser_dl.add_argument('zybook_url',
                           help='URL of the zyBooks textbook to download')
    parser_dl.add_argument('-o', '--output-dir', type=path_arg, default='zybooks',
                           help='Directory PDFs will be written to')
    parser_dl.add_argument('-s', '--chapters-slice', type=slice_arg,
                           help='Slice object to limit which chapters should be printed')
    parser_dl.set_defaults(func=dl)

    args = parser.parse_args()

    logging.basicConfig(
        stream=sys.stdout,
        format='%(asctime)s %(levelname)s - %(message)s',
        datefmt='%H:%M:%S',
        level=log_levels[min(args.verbosity, max(log_levels.keys()))]
    )

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=args.headless)
        try:
            context = browser.new_context(storage_state=args.auth_file)
        except FileNotFoundError:
            context = browser.new_context()
        with context.new_page() as page:
            args.func(page, args)
        if args.func == authenticate.authenticate:
            context.storage_state(path=args.auth_file)


if __name__ == '__main__':
    main()