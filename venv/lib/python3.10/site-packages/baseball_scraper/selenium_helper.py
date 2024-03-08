from selenium import webdriver
import tempfile
import time
import os


class Downloader:
    """Uses Selenium to download a file from a javascript rich website

    :param uri: URI of the file to download
    :type uri: str
    :param file_name: The expected file name that we are going to download.
    This is the file name that is assigned by the website.  You can use the
    save() API to save it to local file of your choosing.
    :type file_name: str
    """
    def __init__(self, uri, file_name):
        self.download_dir = tempfile.TemporaryDirectory(
            prefix="baseball_scraper")
        self.driver = None
        self.uri = uri
        self.file_name = file_name
        self.downloaded = False

    def download_by_clicking(self, elem_type, element_name):
        """Download a file by clicking on the selenium element in the page

        The page we are looking at is the URI that was passed during the
        construction of the class.  You specify what on the page we need to
        click in order to initiate the message.

        :param elem_type: The type of the element on the page.  These are known
        as locator strategies from the selenium.webdriver.common.by module.
        :type elem_type: selenium.webdriver.common.by.By
        :param elem_name: Element name on the page.  The type of element is
        defined by the elem_type parm.
        :type elem_name: str
        """
        try:
            self._start_selenium()
            self.driver.maximize_window()
            self.driver.implicitly_wait(15)
            self.driver.get(self.uri)
            self.driver.find_element(elem_type, element_name).click()
            self._wait_for_download(60)
            self.downloaded = True
        finally:
            self._end_selenium()

    def _wait_for_download(self, timeout):
        cur_time = 0
        file_name = self.downloaded_file()
        while cur_time < timeout:
            if os.path.exists(file_name):
                return
            time.sleep(1)
        raise RuntimeError("Timeout waiting for downloaded file to appear")

    def downloaded_file(self):
        """Return the full path name of the downloaded file

        :return: Path name of the downloaded file
        :rtype: str
        """
        return self.download_dir.name + "/" + self.file_name

    def _start_selenium(self):
        if self.driver is None:
            options = webdriver.ChromeOptions()
            # Ideally we should run chrome headless.  But using that we are not
            # able to download a file.  So I have comment this out for now.
            # This is a recent github issue that tracks the headless download
            # problems: https://github.com/TheBrainFamily/chimpy/issues/108
            # options.add_argument('headless')
            options.add_experimental_option("prefs", {
                "download.default_directory": self.download_dir.name,
                "profile.default_content_settings.popups": 0,
                "download.prompt_for_download": False,
            })
            self.driver = webdriver.Chrome(chrome_options=options)

    def _end_selenium(self):
        if self.driver is not None:
            self.driver.close()
            self.driver = None
