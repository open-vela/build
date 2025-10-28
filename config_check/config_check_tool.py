#
# Copyright (C) 2025 Xiaomi Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.
#

import yaml
import typer
from pathlib import Path

import config_checker

pwd = script_path = Path(__file__).resolve().parent
root = pwd.parent.parent

app = typer.Typer(help="", add_completion=False)


def process_config_refs(subsys, category, config_refs, config_dir, output_dir):
    if not config_refs:
        return
    refs_path = Path(root / config_refs)
    if not refs_path.exists():
        return

    output = Path(f"{output_dir}/{subsys}/{category}.txt")
    config_checker.generate_out_report(config_dir, refs_path, output)


@app.command("check")
def check(
    yaml_config: str = typer.Option(
        f"{pwd}/config_check_conf.yml", help="yaml config file path"
    ),
    binary: str = typer.Option(f"{pwd}/..", help="binary dir"),
    output: str = typer.Option(f"{pwd}/..", help="output dir"),
):
    yaml_path = Path(yaml_config)
    config_h_path = Path(f"{binary}/include/nuttx/config.h")
    if not yaml_path.exists():
        print(f"ERROR:{yaml_path} not exists!")
        return
    if not config_h_path.exists():
        print(f"ERROR:{config_h_path} not exists!")
        return
    with open(yaml_path, "r") as f:
        data = yaml.safe_load(f)
    for sub_system in data:
        for category in data[sub_system]:
            for category_name, refs_path in category.items():
                process_config_refs(
                    sub_system, category_name, refs_path, config_h_path, output
                )


if __name__ == "__main__":
    app()
