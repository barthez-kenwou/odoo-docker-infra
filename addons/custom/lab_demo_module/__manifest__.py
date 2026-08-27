# -*- coding: utf-8 -*-
{
    "name": "Lab Demo Module",
    "version": "18.0.1.0.0",
    "summary": "Minimal addon proving the CI/CD pipeline end-to-end.",
    "description": """
Minimal custom addon for the Odoo DevSecOps lab.

Exists purely to give the build/test/scan/deploy pipeline something real to
exercise: a model, an access rule, and a unit test. Not business logic.
""",
    "author": "Odoo DevSecOps Lab",
    "license": "LGPL-3",
    "category": "Tools",
    "depends": ["base"],
    "data": [
        "security/ir.model.access.csv",
    ],
    "installable": True,
    "application": False,
    "auto_install": False,
}
