# 脚本用例

| 编号 | 检查 | 脚本 |
| --- | --- | --- |
| PKG-01 | 签名有效，应用身份与当前源码一致，arm64 最低系统和所需资源完整 | [package.test.py](package.test.py) |

从仓库根目录传入同一源码版本构建的 `.app`。修改构建流程时可分别验证 Debug 和 Release。发布验收使用从待发布 ZIP 解出的应用。

```sh
python3 skills/fluor4me-regression/tests/script/package.test.py '/path/to/Fluor4me.app'
```

需要构建时，使用 macOS Command Line Tools 和仓库已有的[构建命令](../../../../scripts/build-app.py)。先设置下载用的 HTTPS 代理。以下命令将产物放进独立目录，结束后将该目录移入系统废纸篓。

```sh
fluor_test_dir="$(mktemp -d)"
./scripts/build-app.py --sign - --output "$fluor_test_dir/Fluor4me.app"
python3 skills/fluor4me-regression/tests/script/package.test.py "$fluor_test_dir/Fluor4me.app"
```
