classdef ParamSetBrowser_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure         matlab.ui.Figure
        ModelNameLabel   matlab.ui.control.Label
        Button           matlab.ui.control.Button
        ParamSetUITable  matlab.ui.control.Table
        ContextMenu      matlab.ui.container.ContextMenu
        RefreshMenu      matlab.ui.container.Menu
    end

    % 参数组浏览器 APP
    % 以图形界面方式详细展示"参数扫描"中所有并行仿真所使用的参数组信息。
    % author: muzing <muzi2001@foxmail.com>

    % 此 APP 有两种工作模式：
    % 1.作为 SimConfigTool APP（主程序）的从属窗口（子程序）启动，显示参数组信息
    % 2.作为独立 APP 启动，从基础工作区 simIn 变量中读取解析参数组信息并显示

    properties (Access = private)
        icon = 'icon.png';
        CallingApp % 调用者（主程序APP）
        simIn % SimulationInput 对象数组
        independent % 工作模式标志位，作为从属（False）还是独立（True）APP运行
    end
    
    properties (Access = public)
        paramSetTable % 参数组表
        paramPrefix = 'Param_' % 参数前缀名，Simulink 模型中参数模块均应用此前缀命名
    end

    methods (Access = public)

        function getParamSets(app)
            % 获取实际设置的所有仿真任务的参数组

            if app.independent
                % 作为独立APP运行
                try
                    app.simIn = evalin("base", "simIn");
                catch
                    uialert(app.UIFigure, ['在基础工作区中找不到名为 "simIn" 的变量，',...
                        '请检查后右键刷新重试。'], ...
                    '错误', 'Icon', 'error');
                    return
                end
                
                paramNameArray = strings(100, 1);
                % 与下文的循环求值过程高度重复，这么写不好，但暂时想不出更好的方法了
                for index = 1:length(app.simIn(1).Variables)
                    variableName = app.simIn(1).Variables(index).Name;
                    if startsWith(variableName, app.paramPrefix)
                        paramName = erase(variableName, app.paramPrefix);
                        paramNameArray(index) = paramName;
                    end
                end
                paramNameArray = paramNameArray(paramNameArray~="");
            else
                % 作为从属APP运行
                app.simIn = app.CallingApp.simIn;
                paramNameArray = app.CallingApp.paramAllTable.Properties.RowNames;
            end

            app.paramSetTable = getParamSetTable(app.simIn, paramNameArray,...
                app.paramPrefix);
            app.updateUiTable();
            app.ModelNameLabel.Text = app.simIn(1).ModelName;
        end

    end

    methods (Access = private)

        function updateUiTable(app)
            % 将数据表（app.paramSetTable）的数据同步到 UI表（app.ParamSetUITable）上
            app.ParamSetUITable.Data = app.paramSetTable;
            app.ParamSetUITable.RowName = app.paramSetTable.Properties.RowNames;
            app.ParamSetUITable.ColumnName = app.paramSetTable.Properties.VariableNames;
        end
    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, varargin)
            % 整个 APP 启动时的回调函数

            if ~isempty(varargin)
                % 作为 SimParamSweepTool 主 APP 的从属 APP 启动
                app.independent = false;
                app.CallingApp = varargin{:};
                app.paramPrefix = app.CallingApp.paramPrefix;
            else
                % 作为独立 APP 启动
                app.independent = true;
            end

            app.UIFigure.Name = '参数组浏览器';
            app.UIFigure.Icon = app.icon;
            app.getParamSets();
        end

        % Button pushed function: Button
        function ButtonPushed(app, event)
            % "导出至基础工作区"按钮回调函数

            assignin("base", "paramSetTable", app.paramSetTable);
        end

        % Menu selected function: RefreshMenu
        function RefreshMenuSelected(app, event)
            % "刷新"上下文菜单回调函数
            
            if app.independent
                app.getParamSets();
            else
                % 作为从属APP运行时，界面数据刷新由主APP控制，无需用户手动操作刷新
                return
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 648 462];
            app.UIFigure.Name = 'MATLAB App';

            % Create ParamSetUITable
            app.ParamSetUITable = uitable(app.UIFigure);
            app.ParamSetUITable.ColumnName = {'参数1'; '参数2'; '参数3'; '参数4'};
            app.ParamSetUITable.RowName = {};
            app.ParamSetUITable.Position = [30 71 582 323];

            % Create Button
            app.Button = uibutton(app.UIFigure, 'push');
            app.Button.ButtonPushedFcn = createCallbackFcn(app, @ButtonPushed, true);
            app.Button.Position = [265 24 111 23];
            app.Button.Text = '导出至基础工作区';

            % Create ModelNameLabel
            app.ModelNameLabel = uilabel(app.UIFigure);
            app.ModelNameLabel.FontSize = 14;
            app.ModelNameLabel.Tooltip = {'Simulink 模型'};
            app.ModelNameLabel.Position = [35 409 282 32];
            app.ModelNameLabel.Text = '';

            % Create ContextMenu
            app.ContextMenu = uicontextmenu(app.UIFigure);

            % Create RefreshMenu
            app.RefreshMenu = uimenu(app.ContextMenu);
            app.RefreshMenu.MenuSelectedFcn = createCallbackFcn(app, @RefreshMenuSelected, true);
            app.RefreshMenu.Text = '刷新';
            
            % Assign app.ContextMenu
            app.ParamSetUITable.ContextMenu = app.ContextMenu;

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ParamSetBrowser_exported(varargin)

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.UIFigure)

                % Execute the startup function
                runStartupFcn(app, @(app)startupFcn(app, varargin{:}))
            else

                % Focus the running singleton app
                figure(runningApp.UIFigure)

                app = runningApp;
            end

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end