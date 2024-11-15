"""Setup file."""

from setuptools import find_namespace_packages, setup

package = "miniwdl"

setup(
    name=package,
    description="Workflow Description Language (WDL) local runner & developer toolkit",
    long_description="Workflow Description Language (WDL) local runner & developer toolkit",
    url="https://github.com/BioStrand/miniwdl",
    packages=find_namespace_packages(include=["biostrand.*"]),
    install_requires=[],
    extras_require={},
    zip_safe=False,
    include_package_data=True,
    package_data={},
    entry_points={
        "console_scripts": [
            "miniwdl = WDL.CLI:main",
        ],
    },
)