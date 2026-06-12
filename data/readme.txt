操作指南 

路径编辑：双击路径项直接修改 
标签管理：双击标签可重命名；右键可新增 / 删除标签 
路径管理：右键可快速添加 / 删除清理路径 
权限说明：执行清理时会自动请求管理员权限，确保清理生效 
日志查看：清理完成后，在工具同级目录的 clean_log 文件夹中查看清理日志

规则语法支持：
1.完整路径（带双引号） "C:\Users\Taitaile\AppData\Local\authorwrite-updater"

2.系统环境变量 "%LOCALAPPDATA%\authorwrite-updater"

3.路径（不推荐）C：\Users\Taitaile\AppData\Local\authorwrite-updater

已知局限性： 
文件占用限制：正在被程序占用的文件 / 文件夹无法清理 
路径固定要求：随机生成、无固定路径的文件夹不支持清理 
权限限制：无访问 / 修改权限的系统目录，本工具无法强制清理，需手动提权处理