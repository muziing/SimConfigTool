# 参与 SCT 开发

非常感谢每一位为 SCT 软件开发提供贡献的朋友。请参考本文档中提及的方式与注意事项。

## mlapp 二进制源码

由于 MATLAB APP Designer 以 `.mlapp` 私有二进制格式保存源码，不利于在 Git 中比较差异，故应在 `git commit` 前先使用导出功能将源码转换为 `.m` 文件（文件名使用默认的 <源mlapp名_exported.m>），然后将 `.mlapp` 与对应的 `.m` 文件在同一次 commit 中提交。
