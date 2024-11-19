"""Setup file."""

from setuptools import find_namespace_packages, setup

package = "biostrand-miniwdl"
version = "0.0.2"

setup(
    name=package,
    description="Workflow Description Language (WDL) local runner & developer toolkit",
    long_description="Workflow Description Language (WDL) local runner & developer toolkit",
    url="https://github.com/BioStrand/miniwdl",
    packages=find_namespace_packages(include=["WDL", "WDL.*"]),
    install_requires=[],
    extras_require={},
    zip_safe=False,
    include_package_data=True,
    package_data={},
    entry_points={
        "console_scripts": [
            "biostrand-miniwdl = WDL.CLI:main",
        ],
    },
)