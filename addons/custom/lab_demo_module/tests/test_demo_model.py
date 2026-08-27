# -*- coding: utf-8 -*-
from odoo.exceptions import ValidationError
from odoo.tests.common import TransactionCase, tagged


@tagged("post_install", "-at_install")
class TestLabDemoRecord(TransactionCase):
    """Run in CI via:
    odoo -d $DB --test-enable --stop-after-init -i lab_demo_module
    (see .github/workflows/pr-checks.yml and `make test-unit`).
    """

    def test_create_record(self):
        record = self.env["lab.demo.record"].create({"name": "CI smoke record"})
        self.assertTrue(record.id)
        self.assertTrue(record.active)

    def test_blank_name_rejected(self):
        with self.assertRaises(ValidationError):
            self.env["lab.demo.record"].create({"name": "   "})

    def test_default_ordering_by_name(self):
        Record = self.env["lab.demo.record"]
        Record.create({"name": "Zebra"})
        Record.create({"name": "Alpha"})
        names = Record.search([]).mapped("name")
        self.assertEqual(names, sorted(names))
