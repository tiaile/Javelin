# Javelin
一款支持自定义清理路径的系统缓存清理脚本工具，专注于 C 盘缓存一键清理，操作简单、规则灵活可配置。
<img width="1180" height="682" alt="image" src="https://github.com/user-attachments/assets/773bfb16-af02-41b9-a12c-6bd329f7c04f" />

快速使用
1.将仓库内所有文件下载至同一文件夹中
2.右键以管理员身份运行 .ps1 脚本启动工具

规则配置（核心步骤）
1.打开工具后，先编辑左侧规则文件，检查默认路径配置
2.按需添加 / 删除需要清理的路径，保存后规则自动生效
3.确认规则无误后，点击「执行规则」，一键清理 C 盘缓存

<img width="323" height="96" alt="9b580cf7e5f48987a18966cf727422f3" src="https://github.com/user-attachments/assets/d538400e-c8cb-4853-b450-23e3f82fe761" />

操作指南
路径编辑：双击路径项直接修改
标签管理：双击标签可重命名；右键可新增 / 删除标签
路径管理：右键可快速添加 / 删除清理路径
权限说明：执行清理时会自动请求管理员权限，确保清理生效
日志查看：清理完成后，在工具同级目录的 clean_log 文件夹中查看清理日志

规则语法支持
支持三种路径写法，推荐使用带引号或环境变量写法

1.完整路径（带双引号）
"C:\Users\Taitaile\AppData\Local\authorwrite-updater"

2.系统环境变量
"%LOCALAPPDATA%\authorwrite-updater"

3.纯路径（不推荐）
C:\Users\Taitaile\AppData\Local\authorwrite-updater

已知局限性
文件占用限制：正在被程序占用的文件 / 文件夹无法清理
路径固定要求：随机生成、无固定路径的文件夹不支持清理
权限限制：无访问 / 修改权限的系统目录，本工具无法强制清理，需手动提权处理
