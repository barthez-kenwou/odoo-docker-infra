# -*- coding: utf-8 -*-
from odoo import api, fields, models
from odoo.exceptions import ValidationError


class LabDemoRecord(models.Model):
    """A trivial model used only to exercise CRUD + a constraint in tests.

    Kept intentionally boring: the point of this addon is to prove the
    pipeline (build -> unit test -> scan -> deploy) works, not to showcase
    Odoo ORM features.
    """

    _name = "lab.demo.record"
    _description = "Lab Demo Record"
    _order = "name"

    name = fields.Char(required=True, index=True)
    note = fields.Text()
    active = fields.Boolean(default=True)

    @api.constrains("name")
    def _check_name_not_blank(self):
        for record in self:
            if not record.name or not record.name.strip():
                raise ValidationError("The name must not be blank.")
