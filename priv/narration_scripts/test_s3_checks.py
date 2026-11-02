#!/usr/bin/env python3
"""The recording script's S3 checks, against a stubbed S3: no network, no keys.

    python3 priv/narration_scripts/test_s3_checks.py

What they guard is money: a recording must never be paid for twice because
an S3 error was read as "not there", and a live file must never be replaced
before it is archived.
"""
import importlib.util, os, unittest

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("recording", os.path.join(HERE, "generate_frederick.py"))
recording = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recording)


class S3Error(Exception):
    """Shaped like botocore's ClientError: the code is in .response."""
    def __init__(self, code):
        super().__init__(code)
        self.response = {"Error": {"Code": code}}


class StubS3:
    """head_object answers from a table: an ETag, or an error code to raise."""
    def __init__(self, answers):
        self.answers = answers

    def head_object(self, Bucket, Key):
        answer = self.answers[Key]
        if answer.startswith("error:"):
            raise S3Error(answer.split(":", 1)[1])
        return {"ETag": answer}


LIVE, ARCHIVE = "voices/frederick/a.mp3", "voices/frederick_pre_meditative/a.mp3"


class HeadEtag(unittest.TestCase):
    def test_an_existing_object_gives_its_etag(self):
        self.assertEqual(recording.head_etag(StubS3({LIVE: '"abc"'}), "b", LIVE), '"abc"')

    def test_a_404_is_missing(self):
        self.assertIsNone(recording.head_etag(StubS3({ARCHIVE: "error:404"}), "b", ARCHIVE))

    def test_a_403_stops_the_run_unless_the_caller_has_read_the_tree(self):
        s3 = StubS3({ARCHIVE: "error:403"})
        with self.assertRaises(S3Error):
            recording.head_etag(s3, "b", ARCHIVE)
        self.assertIsNone(recording.head_etag(s3, "b", ARCHIVE, missing_on_403=True))

    def test_any_other_error_stops_the_run_even_after_a_read(self):
        for code in ("500", "SlowDown", "InternalError", ""):
            with self.assertRaises(Exception):
                recording.head_etag(StubS3({ARCHIVE: f"error:{code}"}), "b", ARCHIVE,
                                    missing_on_403=True)


class AlreadyReplaced(unittest.TestCase):
    """The decision the ranked run makes before paying for a recording."""
    def test_no_archive_yet_means_record_it(self):
        self.assertFalse(recording.already_replaced('"live"', None))

    def test_live_differs_from_its_archive_means_done(self):
        self.assertTrue(recording.already_replaced('"new"', '"old"'))

    def test_live_still_the_archived_file_means_the_upload_failed(self):
        self.assertFalse(recording.already_replaced('"old"', '"old"'))


class TheFirstRunWithEmptyArchives(unittest.TestCase):
    """Abraham's first run, 2 Nov: the archive prefix is empty and the upload
    user has no s3:ListBucket, so the archive answers 403."""
    def check(self, answers):
        s3 = StubS3(answers)
        live = recording.head_etag(s3, "b", LIVE)
        old = recording.head_etag(s3, "b", ARCHIVE, missing_on_403=live is not None)
        return live, old

    def test_a_readable_live_file_makes_the_archive_403_read_as_missing(self):
        live, old = self.check({LIVE: '"live"', ARCHIVE: "error:403"})
        self.assertEqual((live, old), ('"live"', None))
        self.assertFalse(recording.already_replaced(live, old))

    def test_a_403_on_the_live_file_stops_before_anything_is_paid(self):
        with self.assertRaises(S3Error):
            self.check({LIVE: "error:403", ARCHIVE: "error:403"})

    def test_an_existing_archive_is_still_seen(self):
        live, old = self.check({LIVE: '"new"', ARCHIVE: '"old"'})
        self.assertTrue(recording.already_replaced(live, old))


if __name__ == "__main__":
    unittest.main()
