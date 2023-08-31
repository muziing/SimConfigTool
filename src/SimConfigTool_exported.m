classdef SimConfigTool_exported < matlab.apps.AppBase
    %SIMCONFIGTOOL_EXPORTED 综合Simulink仿真任务配置工具
    %   以图形化方式集成了选择模型、选择数据文件、参数扫描、调整仿真模式与停止时间、
    %   并行仿真、快捷后处理等仿真常用功能。无需修改模型文件即可实现绝大多数仿真需求。
    %   author: muzing <muzi2001@foxmail.com>

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                       matlab.ui.Figure
        MenuFile                       matlab.ui.container.Menu
        OpenSimulinkFileMenu           matlab.ui.container.Menu
        Quit                           matlab.ui.container.Menu
        Menu                           matlab.ui.container.Menu
        MenuHelp                       matlab.ui.container.Menu
        HelpMenu                       matlab.ui.container.Menu
        AboutMenu                      matlab.ui.container.Menu
        GridLayout6                    matlab.ui.container.GridLayout
        StatusBarLabel                 matlab.ui.control.Label
        TabGroup                       matlab.ui.container.TabGroup
        Tab                            matlab.ui.container.Tab
        GridLayout                     matlab.ui.container.GridLayout
        ModelBrowseButton              matlab.ui.control.Button
        SimulinkEditField              matlab.ui.control.EditField
        SimulinkEditFieldLabel         matlab.ui.control.Label
        ParamTab                       matlab.ui.container.Tab
        GridLayout4                    matlab.ui.container.GridLayout
        ParamCombinationCount          matlab.ui.control.Label
        ParamAllDoneButton             matlab.ui.control.Button
        ParamUITable                   matlab.ui.control.Table
        ParamStepLabel                 matlab.ui.control.Label
        ParamTempSaveButton            matlab.ui.control.Button
        ParamValueStep                 matlab.ui.control.Spinner
        ParamValueMax                  matlab.ui.control.NumericEditField
        ParamValueMaxLabel             matlab.ui.control.Label
        ParamValueMin                  matlab.ui.control.NumericEditField
        ParamIsToSweep                 matlab.ui.control.CheckBox
        ParamSelector                  matlab.ui.control.DropDown
        ParamValueMinLabel             matlab.ui.control.Label
        Label                          matlab.ui.control.Label
        RunSimTab                      matlab.ui.container.Tab
        GridLayout2                    matlab.ui.container.GridLayout
        SimFcnDropDown                 matlab.ui.control.DropDown
        Label_16                       matlab.ui.control.Label
        Label_12                       matlab.ui.control.Label
        Label_11                       matlab.ui.control.Label
        Label_10                       matlab.ui.control.Label
        RunSimButton                   matlab.ui.control.Button
        UseFastRestartCheckBox         matlab.ui.control.CheckBox
        StopOnErrorCheckBox            matlab.ui.control.CheckBox
        ShowSimulationManagerCheckBox  matlab.ui.control.CheckBox
        ShowProgressCheckBox           matlab.ui.control.CheckBox
        SimStopTimeEditField           matlab.ui.control.NumericEditField
        SimModeDropDown                matlab.ui.control.DropDown
        Label_8                        matlab.ui.control.Label
        PostProcessTab                 matlab.ui.container.Tab
        GridLayout3                    matlab.ui.container.GridLayout
        PostResultBrowseButton         matlab.ui.control.Button
        PostResultEditField            matlab.ui.control.EditField
        Label_15                       matlab.ui.control.Label
        RunEasyPostProcessButton       matlab.ui.control.Button
        ParamSetEditField              matlab.ui.control.EditField
        Label_13                       matlab.ui.control.Label
        OpenParamSetBrowserButton      matlab.ui.control.Button
        EasyPostProcessLabel           matlab.ui.control.Label
        OutPortUITable                 matlab.ui.control.Table
        OthersTab                      matlab.ui.container.Tab
        GridLayout5                    matlab.ui.container.GridLayout
        Label_17                       matlab.ui.control.Label
        ExportParamTableButton         matlab.ui.control.Button
        ExportSimInButton              matlab.ui.control.Button
    end


    properties (Access = private)
        easyPostProceResultPath = '' % 快捷后处理结果存储路径
        outpoartAllTable % 保存outport是否用于快捷后处理的数据表格
        simIsRunning = false % 仿真正在运行标志位
        helpDoc % 帮助文档，启动时从HTML文件中读取实际内容
        aboutDoc % 关于文档，启动时从文本文件中读取实际内容
        icon = 'icon.png';
        paramSetBrowserApp % 参数组浏览器 APP
    end

    properties (Access = public)
        simulinkModelFile = '' % Simulink 模型文件
        paramPrefix = 'Param_' % 参数前缀名，凡 Simulink 模型中应为算法参数的模型工作区变量，均用此前缀命名
        outportPrefix = 'ModelOutport' % 模型输出端口前缀名，凡模型中应用于快捷后处理的输出端口模块，均用此前缀命名
        simStopTime = "-1" % 仿真停止时间，字符串类型，由数据文件中时间戳或用户输入决定，
        % -1 为特殊值，表示由模型内部决定
        paramCombinationSum = 1 % 参数组合总数
        paramAllTable % 参数数值表，在此表中保存数据、在 app.ParamUITable 中显示数据
        simIn = Simulink.SimulationInput % SimulationInput 对象数组
        simOut % 仿真结果对象数组
    end

    methods (Access = private)

        function loadModelParam(app)
            %% 从模型中读取加载参数信息

            % 加载模型工作区、获取其中存储的所有变量
            modelWorkeSpace = get_param(app.simulinkModelFile, 'ModelWorkspace');
            mdlWsVariables = whos(modelWorkeSpace);

            paramVariableIndex = zeros(length(mdlWsVariables), 1);
            for index = 1:length(mdlWsVariables)
                if startsWith(mdlWsVariables(index).name, app.paramPrefix)
                    paramVariableIndex(index) = index;
                end
            end
            paramVariableIndex = paramVariableIndex(paramVariableIndex~=0);

            paramVariables = mdlWsVariables(paramVariableIndex); % 结构体数组

            if isempty(paramVariables)
                uialert(app.UIFigure, "在该 Simulink 模型工作区中找不到参数变量。" + ...
                    "请重新选择其他模型文件，或根据帮助文档提示修改模型", ...
                    '错误', 'Icon', 'error');
                app.showStatusText(['已加载模型 ', app.simulinkModelFile, ...
                    '，但有错误']);
                return
            end

            paramNames = strings(length(paramVariables), 1);
            paramDefVals = zeros(length(paramVariables), 1);
            for index=1:length(paramVariables)
                % 获取参数名
                paramNames(index) = erase(paramVariables(index).name, app.paramPrefix);
                % 获取存储在模型工作区的参数默认值
                paramDefVals(index) = getVariable(modelWorkeSpace, ...
                    paramVariables(index).name);
            end

            % 将参数名添加到选择器下拉控件
            app.ParamSelector.Items = paramNames;

            % 创建参数数据表与处理参数UI表
            app.paramAllTable = table(paramDefVals, paramDefVals, ...
                ones(length(paramNames), 1), false(length(paramNames), 1), ...
                'RowName', paramNames);
            app.paramAllTable.Properties.VariableNames = ["min", "max", ...
                "step", "isToSweep"];
            app.ParamUITable.RowName = app.paramAllTable.Properties.RowNames;
            app.paramTableUpdated();

            % 用参数的默认值更新最小/最大/步长输入框
            app.ParamSelectorValueChanged();
        end

        function paramTableUpdated(app)
            %% 每当参数数据表格被更新，就应调用一次此函数

            % 更新界面表格
            app.ParamUITable.Data = app.paramAllTable;

            % 更新参数组合数
            app.paramCombinationSum = 1;
            paramCombinationArray = zeros(height(app.paramAllTable), 0);
            for index = 1:height(app.paramAllTable)
                paramCombinationArray(index) = length(app.paramAllTable.min(index):...
                    app.paramAllTable.step(index):...
                    app.paramAllTable.max(index));
            end

            if all(paramCombinationArray)
                app.paramCombinationSum = prod(paramCombinationArray);
            end

            app.ParamCombinationCount.Text = ['参数组合总数：', ...
                sprintf('%04d',app.paramCombinationSum)];

            if app.paramCombinationSum >= 1
                % 存在有效的参数组合，激活"完成配置"按钮
                app.ParamAllDoneButton.Enable = 'on';
            else
                app.ParamAllDoneButton.Enable = 'off';
            end
        end

        function makeSimIn(app)
            %% 构造 SimulationInput 对象，配置参数设置

            app.simIn = Simulink.SimulationInput;
            app.simIn(1:app.paramCombinationSum) = Simulink.SimulationInput(...
                app.simulinkModelFile);

            if isempty(app.paramAllTable)
                % 该模型中没有任何算法参数的情况
                return
            end
        end

        function setSimIn(app)
            %% 设置 app.simIn 对象的其他非参数属性
            % 由于在界面上此部分功能与参数设置功能分属不同区域，故在函数实现上亦
            % 独立于 app.setSimInParam()
            
            % 建立UI上仿真模式中文文本与 'SimulationMode' 参数值之间的映射关系
            simModeMap = containers.Map(["普通", "加速", "快速加速"], ...
                ["normal", "accelerator", "rapid-accelerator"]);

            for index = 1:length(app.simIn)

                % 设置仿真结束时间
                if app.simStopTime ~= "-1" % "-1"为特殊值，表示使用模型文件中保存的仿真停止时间
                    app.simIn(index) = app.simIn(index).setModelParameter(...
                        "StopTime", app.simStopTime);
                end

                % 设置仿真模式
                app.simIn(index) = app.simIn(index).setModelParameter('SimulationMode', ...
                    convertStringsToChars(simModeMap(app.SimModeDropDown.Value)));
            end
        end

        function setSimInConstParam(app)
            %% 设置 SimulationInput 对象中非扫描参数

            paramConstTable = app.paramAllTable(~app.paramAllTable.isToSweep, :);

            for simInIndex = 1:length(app.simIn)
                % 设置非扫描参数
                for paramIndex = 1:height(paramConstTable)
                    variableName = [app.paramPrefix, ...
                        paramConstTable.Properties.RowNames{paramIndex}];
                    app.simIn(simInIndex) = app.simIn(simInIndex).setVariable(...
                        variableName, paramConstTable.max(paramIndex), 'Workspace', ...
                        app.simulinkModelFile);
                end
            end
        end

        function setSimInParam(app)
            %% 设置 SimulationInput 中的算法参数

            app.setSimInConstParam();
            paramToSweepTable = app.paramAllTable(app.paramAllTable.isToSweep, :);
            app.simIn = setSimInSweepParam(app.simIn, paramToSweepTable, app.paramPrefix);

            try
                validate(app.simIn);
            catch ME
                uiconfirm(app.UIFigure, ['仿真参数配置失败：', ME.message], ...
                    "出错了", 'Icon', 'error', 'Options','OK');
                app.showStatusText("仿真参数配置失败");
            end

            % 此行代码用布尔运算短路原则才实现了期望功能，不可改变两个条件之间的顺序
            if ~isempty(app.paramSetBrowserApp) && isvalid(app.paramSetBrowserApp)
                % 如果存在参数组浏览器，则刷新其界面
                app.paramSetBrowserApp.getParamSets();
            end
        end

        function easyPostProcessing(app)
            %% 快捷后处理
            
            if isempty(app.outpoartAllTable)
                return
            end

            poartToProceTable = app.outpoartAllTable(app.outpoartAllTable.(1), :);
            poartsToProceArray = poartToProceTable.Properties.RowNames;

            if ~isempty(app.ParamSetEditField.Value)
                ParamSetIndexArray = getUserInputIndexArray(app.ParamSetEditField.Value);
            else
                % 如果用户未显示指定使用哪些参数组，则自动选择所有参数组
                ParamSetIndexArray = 1:app.paramCombinationSum;
            end

            paramSetStrArray = strings;
            timeTableArray = cell(length(ParamSetIndexArray), 1);

            for index = 1:length(ParamSetIndexArray)

                % 构造时间表、绘制存储堆叠图
                resultTimeserieArray = cell(length(poartsToProceArray), 1);
                for outpoartIndex = 1:length(poartsToProceArray)
                    resultTimeserieArray(outpoartIndex) = {app.simOut(...
                        ParamSetIndexArray(index)).get("yout").getElement(...
                        poartsToProceArray{outpoartIndex}).Values};
                end

                timeTableArray(index) = {timeseries2timetable(resultTimeserieArray{:})};
                paramSetStrArray(index) = "ParamSet " + ...
                    num2str(ParamSetIndexArray(index));
            end

            TT_fig = stackedplot(timeTableArray{:});
            TT_fig.LegendLabels = paramSetStrArray; % 设置图例
            saveas(TT_fig, 'Result.fig');
        end

        function parSimParamArray = getParsimParamsArray(app)
            %% 获取用户在界面上配置的 sim/parsim 函数参数

            parSimParamArray = strings;

            if app.ShowProgressCheckBox.Value
                parSimParamArray = [parSimParamArray, "ShowProgress", "on"];
            else
                parSimParamArray = [parSimParamArray, "ShowProgress", "off"];
            end

            if app.ShowSimulationManagerCheckBox.Value
                parSimParamArray = [parSimParamArray, "ShowSimulationManager", "on"];
            else
                parSimParamArray = [parSimParamArray, "ShowSimulationManager", "off"];
            end

            if app.StopOnErrorCheckBox.Value
                parSimParamArray = [parSimParamArray, "StopOnError", "on"];
            else
                parSimParamArray = [parSimParamArray, "StopOnError", "off"];
            end

            if app.UseFastRestartCheckBox.Value
                parSimParamArray = [parSimParamArray, "UseFastRestart", "on"];
            else
                parSimParamArray = [parSimParamArray, "UseFastRestart", "off"];
            end

            parSimParamArray = parSimParamArray(2:end);
        end

        function loadSimOutport(app)
            %% 从模型中读取处理输出，为快捷后处理做准备
            % 筛选出输出端口模块
            outBlocks = find_system(app.simulinkModelFile, 'MatchFilter', ...
                @Simulink.match.activeVariants, ...
                'regexp', 'on', 'name', app.outportPrefix);
            outNames = strings(length(outBlocks), 1);

            if isempty(outBlocks)
                uialert(app.UIFigure, ['在该 Simulink 模型文件中检测不到输出模块，' ...
                    '可能无法进行快捷后处理。请查看帮助文档修改输出模块名。'], ...
                    '警告', 'Icon', 'warning');
                app.RunEasyPostProcessButton.Enable = "off";
                return
            else
                app.RunEasyPostProcessButton.Enable = "on";
            end

            for index=1:length(outBlocks)
                % 获取输出模块中的信号名
                outportSignalName = get_param(outBlocks(index), 'SignalName');

                % 强制检查输出端口是否设置输出信号名
                if isempty(outportSignalName{1})
                    uialert(app.UIFigure, ['输出模块 ', outBlocks{index}, ...
                        ' 未设置信号名称，需要修改模型，否则无法使用快捷后处理功能。'], ...
                    '警告', 'Icon', 'warning');
                    app.showStatusText("模型中部分输出端口未设置信号名称，需要修改。");
                    return
                else
                    outNames(index) = outportSignalName;
                end
            end

            % 将参数名添加到表格
            app.outpoartAllTable = table(false(length(outNames),1), ...
                'RowName', outNames);
            app.OutPortUITable.RowName = app.outpoartAllTable.Properties.RowNames;
            app.OutPortUITable.Data = app.outpoartAllTable;
        end

        function switchUiEnable(app)
            %% 在运行仿真前后，切换部分界面控件的可用性
            % 实现禁止用户在仿真运行时修改界面上的仿真参数的效果
            % 每当 app.simIsRunning 的值发生变化时，就应当调用一次此函数

            if app.simIsRunning
                % "运行仿真"按钮
                app.RunSimButton.Enable = "off";

                % 左侧栏
                app.SimModeDropDown.Enable = "off";
                app.SimStopTimeEditField.Enable = "off";
                app.SimFcnDropDown.Enable = "off";

                % 右侧栏
                app.ShowProgressCheckBox.Enable = "off";
                app.ShowSimulationManagerCheckBox.Enable = "off";
                app.StopOnErrorCheckBox.Enable = "off";
                app.UseFastRestartCheckBox.Enable = "off";

            else
                % 仿真不在运行中，恢复界面控件可用性
                % "运行仿真"按钮
                app.RunSimButton.Enable = "on";

                % 左侧栏
                app.SimModeDropDown.Enable = "on";
                app.SimStopTimeEditField.Enable = "on";
                app.SimFcnDropDown.Enable = "on";

                % 右侧栏
                app.ShowProgressCheckBox.Enable = "on";
                app.ShowSimulationManagerCheckBox.Enable = "on";
                app.StopOnErrorCheckBox.Enable = "on";
                app.UseFastRestartCheckBox.Enable = "on";
            end
        end

        function showStatusText(app, text)
            % 在界面状态栏显示状态提示文本
            app.StatusBarLabel.Text = text;
        end

    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % 整个 APP 启动时的回调函数

            app.UIFigure.Name = "综合Simulink仿真配置工具";
            app.UIFigure.Icon = app.icon;

            % TODO: 通过字符串匹配方式，将帮助文档中的对应内容动态更新为
            % app.paramPrefix、app.outportPrefix 的实际值
            % TODO: CSS美化文档
            app.helpDoc = fileread("helpDoc.html", "Encoding", "UTF-8");
            app.aboutDoc = fileread("aboutDoc.html", "Encoding", "UTF-8");

            app.showStatusText("首次启动和加载模型耗时较长，请耐心等待。");
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            % 关闭整个 APP 窗口时的回调函数

            if app.simIsRunning
                selection = uiconfirm(app.UIFigure, ['仿真正在运行中，' ...
                    '直接关闭此窗口不会停止仿真。' ...
                    '若想中止仿真，可以在仿真管理器中操作；'...
                    '或在命令行中使用键盘快捷键 Ctrl+C。'],...
                    '确定退出？');
                switch selection
                    case 'OK'
                        app.QuitSelected();
                    case 'Cancel'
                        return
                end
            else
                app.QuitSelected();
            end
        end

        % Callback function: ModelBrowseButton, OpenSimulinkFileMenu
        function BrowseSimulinkFileMenuSelected(app, event)
            % 打开 Simulink 模型文件的回调函数

            if app.simIsRunning
                return
            end

            [mdlFullFileName, mdlPath] = uigetfile({'*.slx;*.mdl',...
                'Simulink 模型文件';});

            if ~mdlFullFileName
                if isempty(app.simulinkModelFile)
                    % 用户未选择文件（在文件资源浏览器中点击取消）
                    uialert(app.UIFigure, "未打开有效的 Simulink 模型文件", ...
                        '警告', 'Icon', 'warning');
                    app.showStatusText("尚未打开有效的 Simulink 模型文件");
                else
                    % 虽然用户此次操作未选择文件，但已有先前加载过的模型文件
                    return
                end
            else
                cd(mdlPath); % 以模型文件所在目录作为工作目录，其他路径处理为相对此路径
                app.showStatusText(['正在加载模型 ', app.simulinkModelFile]);
                [~,modelName,~] = fileparts(mdlFullFileName);
                app.simulinkModelFile = modelName; % 后续所有操作需要使用不含后缀名的模型文件名称
                app.SimulinkEditField.Value = mdlFullFileName;

                % 将 Simulink 模型加载到内存中，便于读取参数接口等信息
                load_system(modelName);

                % 处理参数
                app.loadModelParam();

                % 处理输出，为快捷后处理做准备
                app.loadSimOutport();

                % 完成所有模型加载与初始化
                app.showStatusText(['已加载模型 ', app.simulinkModelFile]);
            end
        end

        % Menu selected function: Quit
        function QuitSelected(app, event)
            % 关闭整个程序

            delete(app.paramSetBrowserApp);
            delete(app);
        end

        % Value changed function: ParamIsToSweep
        function ParamIsToSweepValueChanged(app, event)
            % "该参数是否用于扫描复选框"的回调函数

            if app.ParamIsToSweep.Value
                app.ParamValueMin.Visible = 'on';
                app.ParamValueMinLabel.Visible = 'on';
                app.ParamValueStep.Visible = 'on';
                app.ParamStepLabel.Visible = 'on';
                app.ParamValueMaxLabel.Text = '最大值';
            else
                % 若该参数不将用于扫描，则将最大值、步长输入框禁用
                app.ParamValueMin.Visible = 'off';
                app.ParamValueMinLabel.Visible = 'off';
                app.ParamValueStep.Visible = 'off';
                app.ParamStepLabel.Visible = 'off';
                app.ParamValueStep.Value = 1;
                app.ParamValueMaxLabel.Text = '固定值';
                app.ParamValueMin.Value = app.ParamValueMax.Value;
            end
        end

        % Value changed function: ParamSelector
        function ParamSelectorValueChanged(app, event)
            % 参数选择下拉框的回调函数

            % 将数据表中保存的当前设定反赋值给设定框，改善用户体验
            app.ParamValueMin.Value = app.paramAllTable(app.ParamSelector.Value, :).min;
            app.ParamValueMax.Value = app.paramAllTable(app.ParamSelector.Value, :).max;
            app.ParamValueStep.Value = app.paramAllTable(app.ParamSelector.Value, :).step;

            % 将数据表中保存的是否用于扫描的设置反赋值给复选框，改善用户体验
            if app.paramAllTable(app.ParamSelector.Value, :).isToSweep
                app.ParamIsToSweep.Value = 1;
                app.ParamIsToSweepValueChanged();
            else
                app.ParamIsToSweep.Value = 0;
                app.ParamIsToSweepValueChanged();
            end
        end

        % Value changed function: ParamValueMax
        function ParamValueMaxValueChanged(app, event)
            % 参数最大值输入框值变化的回调函数

            if  ~app.ParamIsToSweep.Value
                % 在该参数为非扫描参数固定值时，将最小值同步设置为与最大值相等
                app.ParamValueMin.Value = app.ParamValueMax.Value;
            end

            % 修改最大值时，必须大于当前的最小值
            if app.ParamValueMax.Value < app.ParamValueMin.Value
                % 否则自动设置最大值与最小值相同
                app.ParamValueMax.Value = app.ParamValueMin.Value;
            end
        end

        % Button pushed function: ParamTempSaveButton
        function ParamTempSaveButtonPushed(app, event)
            % "暂存按钮"回调函数

            if isempty(app.simulinkModelFile) || app.simIsRunning
                return
            end

            paramToSweepTable = app.paramAllTable(app.paramAllTable.isToSweep, :);

            if app.ParamIsToSweep.Value && ...
                    height(paramToSweepTable) >= 5 && ...
                    ~any(ismember(paramToSweepTable.Properties.RowNames, ...
                    app.ParamSelector.Value))
                % 用于扫描的参数个数已达上限
                uialert(app.UIFigure, "用于扫描的参数数量已达上限。" + ...
                    "请先将其他待扫描参数设为固定值后再试。", ...
                    '暂存失败', 'Icon', 'error');
                app.ParamIsToSweep.Value = 0;
                app.ParamIsToSweepValueChanged();
                return
            end

            % 更新参数数据表格中的数据
            app.paramAllTable(app.ParamSelector.Value, :) = {...
                app.ParamValueMin.Value, app.ParamValueMax.Value, ...
                app.ParamValueStep.Value, app.ParamIsToSweep.Value};
            app.showStatusText(sprintf("已暂存参数 %s", app.ParamSelector.Value));
            app.paramTableUpdated();
        end

        % Value changed function: ParamValueMin
        function ParamValueMinValueChanged(app, event)
            % 用户修改参数最小值时的回调函数

            % 修改最大值时，必须大于当前的最小值
            if app.ParamValueMin.Value > app.ParamValueMax.Value
                % 否则自动设置最大值与最小值相同
                app.ParamValueMin.Value = app.ParamValueMax.Value;
            end
        end

        % Menu selected function: AboutMenu
        function MenuHelpSelected(app, event)
            % "关于" 菜单按钮的回调函数

            uiconfirm(app.UIFigure, app.aboutDoc, '关于', 'Icon', app.icon, ...
                'Options', 'OK', 'Interpreter', 'html');
        end

        % Button pushed function: ParamAllDoneButton
        function ParamAllDoneButtonPushed(app, event)
            % "参数完成配置"按钮的回调函数

            if isempty(app.simulinkModelFile) || app.simIsRunning
                return
            end

            function paramSetAllDone(app)
                app.makeSimIn();
                app.setSimInParam();
                app.showStatusText("已完成参数配置");
            end

            if app.paramCombinationSum > 200
                userSelection = uiconfirm(app.UIFigure, "参数组合较多，" + ...
                    "仿真耗时可能非常长，确定要继续吗？",...
                    '警告', 'Icon', 'warning', 'Options', {'OK', 'Cancel'});
                switch userSelection
                    case 'OK'
                        paramSetAllDone(app);
                    case 'Cancel'
                        return
                end
            else
                paramSetAllDone(app);
            end
        end

        % Button pushed function: RunSimButton
        function RunSimButtonPushed(app, event)
            % "运行仿真" 按钮的回调函数

            if isempty(app.simulinkModelFile)
                return
            end

            % 再次显式调用"参数完成配置"按钮的回调函数，确保有合法参数
            app.ParamAllDoneButtonPushed();

            % 配置仿真基本设置
            app.setSimIn();
            assignin("base", 'simIn', app.simIn);

            % 获取并行仿真参数
            parsimParamsArray = app.getParsimParamsArray();

            %% 运行仿真

            app.showStatusText("仿真运行中...");
            app.simIsRunning = true;
            app.switchUiEnable()

            try
                tic
                if app.SimFcnDropDown.Value == "串行仿真" || ...
                        app.paramCombinationSum == 1
                    % 当只有一组参数时，使用sim()替代parsim()，额外开销更小、仿真运行更快
                    app.simOut = sim(app.simIn, parsimParamsArray{:});
                else
                    % 运行并行仿真
                    app.simOut = parsim(app.simIn, parsimParamsArray{:});
                end
                toc

                assignin("base", 'simOut', app.simOut);
                app.showStatusText("仿真脚本运行完毕");
            catch ME
                uiconfirm(app.UIFigure, ['仿真运行失败，', ME.message], ...
                    "出错了", 'Icon', 'error', 'Options','OK');
                app.showStatusText("仿真脚本运行失败");
                app.RunSimButton.Enable = "on";
            end

            app.simIsRunning = false;
            app.switchUiEnable();
        end

        % Menu selected function: HelpMenu
        function HelpMenuSelected(app, event)
            % "帮助"菜单按钮的回调函数

            uiconfirm(app.UIFigure, app.helpDoc, "帮助", ...
                'Options','OK', 'Interpreter', 'html');
        end

        % Display data changed function: OutPortUITable
        function OutPortUITableDisplayDataChanged(app, event)
            % 用户操作编辑了界面outport表格的回调函数

            % 将界面outport表格的新数据赋给数据表格
            app.outpoartAllTable = app.OutPortUITable.Data;
        end

        % Value changed function: SimStopTimeEditField
        function SimStopTimeEditFieldValueChanged(app, event)
            % 用户修改仿真停止时间输入框值的回调函数

            app.simStopTime = string(app.SimStopTimeEditField.Value);
        end

        % Callback function: Menu, OpenParamSetBrowserButton
        function OpenParamSetBrowser(app, event)
            % 打开参数组浏览器按钮的回调函数

            if isempty(app.simulinkModelFile) || isempty(app.paramAllTable)
                return
            end

            % 再次显式调用"参数完成配置"按钮的回调函数，确保有合法参数
            app.ParamAllDoneButtonPushed();
            app.paramSetBrowserApp = ParamSetBrowser(app);
        end

        % Value changed function: ParamSetEditField
        function ParamSetEditFieldValueChanged(app, event)
            % 快捷后处理中，用户编辑参数组选择器的回调函数

            % 限制用户输入，只能输入有效的参数组编号
            ParamSetIndexArray = getUserInputIndexArray(app.ParamSetEditField.Value);
            if ~all(ismember(ParamSetIndexArray, 1:app.paramCombinationSum))
                uialert(app.UIFigure, "仿真参数组索引输入无效，请重新输入", ...
                    '警告', 'Icon', 'warning');
                app.ParamSetEditField.Value = "";
            end
        end

        % Button pushed function: PostResultBrowseButton
        function PostResultBrowseButtonPushed(app, event)
            % "浏览快捷后处理结果存储位置"按钮回调函数

            app.easyPostProceResultPath = uigetdir();
            app.PostResultEditField.Value = app.easyPostProceResultPath;
        end

        % Button pushed function: RunEasyPostProcessButton
        function RunEasyPostProcessButtonPushed(app, event)
            % "运行快捷后处理" 按钮回调函数

            if isempty(app.simulinkModelFile) || app.simIsRunning || isempty(app.simOut)
                return
            end

            app.showStatusText("正在运行快捷后处理");
            currentPath = pwd();
            if isempty(app.easyPostProceResultPath)
                % 当用户没有显示指定结果路径时，自动使用当前路径
                app.easyPostProceResultPath = currentPath;
            end
            cd(app.easyPostProceResultPath);

            try
                app.RunEasyPostProcessButton.Enable = "off";
                app.easyPostProcessing();
                % FIXME: 即使 easyPostProcessing 直接返回，亦会提示"运行完毕"
                app.showStatusText("快捷后处理运行完毕");
            catch ME
                % 异常处理
                uiconfirm(app.UIFigure, ['快捷后处理运行失败，', ME.message], ...
                    "出错了", 'Icon', 'error', 'Options','OK');
                app.showStatusText("快捷后处理运行失败");
            end

            cd(currentPath);
            app.RunEasyPostProcessButton.Enable = "on";
        end

        % Button pushed function: ExportSimInButton
        function ExportSimInButtonPushed(app, event)
            % "导出仿真对象至基础工作区"按钮的回调函数

            if isempty(app.simulinkModelFile)
                return
            end

            app.ParamAllDoneButtonPushed();
            app.setSimIn();
            assignin("base", 'simIn', app.simIn);
            app.showStatusText("已将 SimulationInput 数组导出至" + ...
                "基础工作区的 simIn 变量中");
        end

        % Button pushed function: ExportParamTableButton
        function ExportParamTableButtonPushed(app, event)
            % "导出参数组表格至基础工作区"按钮的回调函数

            if isempty(app.simulinkModelFile) || isempty(app.paramAllTable)
                return
            end

            app.ParamAllDoneButtonPushed();
            paramNameArray = app.paramAllTable.Properties.RowNames;
            paramSetTable = getParamSetTable(app.simIn, paramNameArray,...
                app.paramPrefix);
            assignin("base", "paramSetTable", paramSetTable);
            app.showStatusText("已将参数组表格导出至基础工作区的" + ...
                " paramSetTable 变量中");
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Get the file path for locating images
            pathToMLAPP = fileparts(mfilename('fullpath'));

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 656 480];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.Icon = fullfile(pathToMLAPP, 'icon.png');
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            % Create MenuFile
            app.MenuFile = uimenu(app.UIFigure);
            app.MenuFile.Text = '文件';

            % Create OpenSimulinkFileMenu
            app.OpenSimulinkFileMenu = uimenu(app.MenuFile);
            app.OpenSimulinkFileMenu.MenuSelectedFcn = createCallbackFcn(app, @BrowseSimulinkFileMenuSelected, true);
            app.OpenSimulinkFileMenu.Tooltip = {'加载 Simulink 模型文件。'};
            app.OpenSimulinkFileMenu.Text = '打开Simulink模型';

            % Create Quit
            app.Quit = uimenu(app.MenuFile);
            app.Quit.MenuSelectedFcn = createCallbackFcn(app, @QuitSelected, true);
            app.Quit.Tooltip = {'退出程序'};
            app.Quit.Text = '退出';

            % Create Menu
            app.Menu = uimenu(app.UIFigure);
            app.Menu.MenuSelectedFcn = createCallbackFcn(app, @OpenParamSetBrowser, true);
            app.Menu.Tooltip = {'打开参数组浏览器窗口'};
            app.Menu.Text = '参数组浏览器';

            % Create MenuHelp
            app.MenuHelp = uimenu(app.UIFigure);
            app.MenuHelp.Tooltip = {'显示关于信息'};
            app.MenuHelp.Text = '帮助';

            % Create HelpMenu
            app.HelpMenu = uimenu(app.MenuHelp);
            app.HelpMenu.MenuSelectedFcn = createCallbackFcn(app, @HelpMenuSelected, true);
            app.HelpMenu.Text = '帮助';

            % Create AboutMenu
            app.AboutMenu = uimenu(app.MenuHelp);
            app.AboutMenu.MenuSelectedFcn = createCallbackFcn(app, @MenuHelpSelected, true);
            app.AboutMenu.Text = '关于';

            % Create GridLayout6
            app.GridLayout6 = uigridlayout(app.UIFigure);
            app.GridLayout6.ColumnWidth = {450, '1x', 100};
            app.GridLayout6.RowHeight = {30, '1x', 22};
            app.GridLayout6.RowSpacing = 1;
            app.GridLayout6.Padding = [10 1 10 1];

            % Create TabGroup
            app.TabGroup = uitabgroup(app.GridLayout6);
            app.TabGroup.Layout.Row = 2;
            app.TabGroup.Layout.Column = [1 3];

            % Create Tab
            app.Tab = uitab(app.TabGroup);
            app.Tab.Tooltip = {'打开模型、控制脚本与数据文件'};
            app.Tab.Title = '模型与数据';

            % Create GridLayout
            app.GridLayout = uigridlayout(app.Tab);
            app.GridLayout.ColumnWidth = {95, '3x', '1x', 90};
            app.GridLayout.RowHeight = {'1x', 30, 30, 30, '1.25x'};

            % Create SimulinkEditFieldLabel
            app.SimulinkEditFieldLabel = uilabel(app.GridLayout);
            app.SimulinkEditFieldLabel.HorizontalAlignment = 'right';
            app.SimulinkEditFieldLabel.Layout.Row = 2;
            app.SimulinkEditFieldLabel.Layout.Column = 1;
            app.SimulinkEditFieldLabel.Text = 'Simulink 模型';

            % Create SimulinkEditField
            app.SimulinkEditField = uieditfield(app.GridLayout, 'text');
            app.SimulinkEditField.Editable = 'off';
            app.SimulinkEditField.Layout.Row = 2;
            app.SimulinkEditField.Layout.Column = [2 3];

            % Create ModelBrowseButton
            app.ModelBrowseButton = uibutton(app.GridLayout, 'push');
            app.ModelBrowseButton.ButtonPushedFcn = createCallbackFcn(app, @BrowseSimulinkFileMenuSelected, true);
            app.ModelBrowseButton.Tooltip = {'浏览 Simulink 模型文件。'};
            app.ModelBrowseButton.Layout.Row = 2;
            app.ModelBrowseButton.Layout.Column = 4;
            app.ModelBrowseButton.Text = '浏览';

            % Create ParamTab
            app.ParamTab = uitab(app.TabGroup);
            app.ParamTab.Tooltip = {'检视、修改算法模型中的所有参数'};
            app.ParamTab.Title = '算法参数';

            % Create GridLayout4
            app.GridLayout4 = uigridlayout(app.ParamTab);
            app.GridLayout4.ColumnWidth = {200, '1x', '1.6x', '1x', 120};
            app.GridLayout4.RowHeight = {22, 25, 22, '1x', '10.47x', 31};
            app.GridLayout4.ColumnSpacing = 9.2;
            app.GridLayout4.Padding = [9.2 10 9.2 15];

            % Create Label
            app.Label = uilabel(app.GridLayout4);
            app.Label.Layout.Row = 1;
            app.Label.Layout.Column = 1;
            app.Label.Text = '算法参数';

            % Create ParamValueMinLabel
            app.ParamValueMinLabel = uilabel(app.GridLayout4);
            app.ParamValueMinLabel.HorizontalAlignment = 'right';
            app.ParamValueMinLabel.Visible = 'off';
            app.ParamValueMinLabel.Layout.Row = 1;
            app.ParamValueMinLabel.Layout.Column = 2;
            app.ParamValueMinLabel.Text = '最小值';

            % Create ParamSelector
            app.ParamSelector = uidropdown(app.GridLayout4);
            app.ParamSelector.Items = {'Null'};
            app.ParamSelector.ValueChangedFcn = createCallbackFcn(app, @ParamSelectorValueChanged, true);
            app.ParamSelector.Layout.Row = 2;
            app.ParamSelector.Layout.Column = 1;
            app.ParamSelector.Value = 'Null';

            % Create ParamIsToSweep
            app.ParamIsToSweep = uicheckbox(app.GridLayout4);
            app.ParamIsToSweep.ValueChangedFcn = createCallbackFcn(app, @ParamIsToSweepValueChanged, true);
            app.ParamIsToSweep.Text = '将该参数用于扫描';
            app.ParamIsToSweep.Layout.Row = 3;
            app.ParamIsToSweep.Layout.Column = 1;

            % Create ParamValueMin
            app.ParamValueMin = uieditfield(app.GridLayout4, 'numeric');
            app.ParamValueMin.ValueChangedFcn = createCallbackFcn(app, @ParamValueMinValueChanged, true);
            app.ParamValueMin.Visible = 'off';
            app.ParamValueMin.Layout.Row = 1;
            app.ParamValueMin.Layout.Column = 3;

            % Create ParamValueMaxLabel
            app.ParamValueMaxLabel = uilabel(app.GridLayout4);
            app.ParamValueMaxLabel.HorizontalAlignment = 'right';
            app.ParamValueMaxLabel.Layout.Row = 2;
            app.ParamValueMaxLabel.Layout.Column = 2;
            app.ParamValueMaxLabel.Text = '固定值';

            % Create ParamValueMax
            app.ParamValueMax = uieditfield(app.GridLayout4, 'numeric');
            app.ParamValueMax.ValueChangedFcn = createCallbackFcn(app, @ParamValueMaxValueChanged, true);
            app.ParamValueMax.Layout.Row = 2;
            app.ParamValueMax.Layout.Column = 3;

            % Create ParamValueStep
            app.ParamValueStep = uispinner(app.GridLayout4);
            app.ParamValueStep.Limits = [1e-06 Inf];
            app.ParamValueStep.Visible = 'off';
            app.ParamValueStep.Layout.Row = 3;
            app.ParamValueStep.Layout.Column = 3;
            app.ParamValueStep.Value = 1;

            % Create ParamTempSaveButton
            app.ParamTempSaveButton = uibutton(app.GridLayout4, 'push');
            app.ParamTempSaveButton.ButtonPushedFcn = createCallbackFcn(app, @ParamTempSaveButtonPushed, true);
            app.ParamTempSaveButton.Tooltip = {'将左侧配置应用到下方参数表格中'};
            app.ParamTempSaveButton.Layout.Row = 2;
            app.ParamTempSaveButton.Layout.Column = 5;
            app.ParamTempSaveButton.Text = '暂存';

            % Create ParamStepLabel
            app.ParamStepLabel = uilabel(app.GridLayout4);
            app.ParamStepLabel.HorizontalAlignment = 'right';
            app.ParamStepLabel.Visible = 'off';
            app.ParamStepLabel.Layout.Row = 3;
            app.ParamStepLabel.Layout.Column = 2;
            app.ParamStepLabel.Text = '步长';

            % Create ParamUITable
            app.ParamUITable = uitable(app.GridLayout4);
            app.ParamUITable.ColumnName = {'最小值'; '最大值'; '步长'; '用于扫描'};
            app.ParamUITable.RowName = {};
            app.ParamUITable.Layout.Row = 5;
            app.ParamUITable.Layout.Column = [1 5];

            % Create ParamAllDoneButton
            app.ParamAllDoneButton = uibutton(app.GridLayout4, 'push');
            app.ParamAllDoneButton.ButtonPushedFcn = createCallbackFcn(app, @ParamAllDoneButtonPushed, true);
            app.ParamAllDoneButton.Enable = 'off';
            app.ParamAllDoneButton.Layout.Row = 6;
            app.ParamAllDoneButton.Layout.Column = [2 3];
            app.ParamAllDoneButton.Text = '完成配置';

            % Create ParamCombinationCount
            app.ParamCombinationCount = uilabel(app.GridLayout4);
            app.ParamCombinationCount.Tooltip = {'仿真任务数量'};
            app.ParamCombinationCount.Layout.Row = 6;
            app.ParamCombinationCount.Layout.Column = 5;
            app.ParamCombinationCount.Text = '参数组合总数：0001  ';

            % Create RunSimTab
            app.RunSimTab = uitab(app.TabGroup);
            app.RunSimTab.Tooltip = {'配置、运行并行仿真'};
            app.RunSimTab.Title = '仿真';

            % Create GridLayout2
            app.GridLayout2 = uigridlayout(app.RunSimTab);
            app.GridLayout2.ColumnWidth = {'1x', '1x', 35, '1x', '1x'};
            app.GridLayout2.RowHeight = {35, '1x', '1x', '1x', '1x', '1x', '1.5x', 30};
            app.GridLayout2.ColumnSpacing = 20;
            app.GridLayout2.Padding = [10 10 10 18];

            % Create Label_8
            app.Label_8 = uilabel(app.GridLayout2);
            app.Label_8.FontSize = 14;
            app.Label_8.Tooltip = {'sim/parsim 参数'};
            app.Label_8.Layout.Row = 1;
            app.Label_8.Layout.Column = 4;
            app.Label_8.Text = '仿真运行设置';

            % Create SimModeDropDown
            app.SimModeDropDown = uidropdown(app.GridLayout2);
            app.SimModeDropDown.Items = {'普通', '加速', '快速加速'};
            app.SimModeDropDown.Tooltip = {'选择仿真模式，需要模型本身支持该模式才能运行。'};
            app.SimModeDropDown.Layout.Row = 2;
            app.SimModeDropDown.Layout.Column = 2;
            app.SimModeDropDown.Value = '加速';

            % Create SimStopTimeEditField
            app.SimStopTimeEditField = uieditfield(app.GridLayout2, 'numeric');
            app.SimStopTimeEditField.ValueDisplayFormat = '%11.7g';
            app.SimStopTimeEditField.ValueChangedFcn = createCallbackFcn(app, @SimStopTimeEditFieldValueChanged, true);
            app.SimStopTimeEditField.HorizontalAlignment = 'left';
            app.SimStopTimeEditField.Tooltip = {'显式指定仿真停止时间。"-1"表示使用模型内部的停止时间。'};
            app.SimStopTimeEditField.Layout.Row = 3;
            app.SimStopTimeEditField.Layout.Column = 2;
            app.SimStopTimeEditField.Value = -1;

            % Create ShowProgressCheckBox
            app.ShowProgressCheckBox = uicheckbox(app.GridLayout2);
            app.ShowProgressCheckBox.Tooltip = {'在命令行窗口中查看仿真的进度。'};
            app.ShowProgressCheckBox.Text = '显示仿真进度 ShowProgress';
            app.ShowProgressCheckBox.Layout.Row = 2;
            app.ShowProgressCheckBox.Layout.Column = [4 5];
            app.ShowProgressCheckBox.Value = true;

            % Create ShowSimulationManagerCheckBox
            app.ShowSimulationManagerCheckBox = uicheckbox(app.GridLayout2);
            app.ShowSimulationManagerCheckBox.Tooltip = {'使用仿真管理器来监视仿真。'};
            app.ShowSimulationManagerCheckBox.Text = '显示仿真管理器 ShowSimulationManager';
            app.ShowSimulationManagerCheckBox.Layout.Row = 3;
            app.ShowSimulationManagerCheckBox.Layout.Column = [4 5];

            % Create StopOnErrorCheckBox
            app.StopOnErrorCheckBox = uicheckbox(app.GridLayout2);
            app.StopOnErrorCheckBox.Tooltip = {'在遇到错误时将停止执行仿真。'};
            app.StopOnErrorCheckBox.Text = '出错即停止 StopOnError';
            app.StopOnErrorCheckBox.Layout.Row = 4;
            app.StopOnErrorCheckBox.Layout.Column = [4 5];
            app.StopOnErrorCheckBox.Value = true;

            % Create UseFastRestartCheckBox
            app.UseFastRestartCheckBox = uicheckbox(app.GridLayout2);
            app.UseFastRestartCheckBox.Tooltip = {'仿真使用快速重启在工作进程上运行。如果仿真失败，请尝试关闭此项。'};
            app.UseFastRestartCheckBox.Text = '快速重启 UseFastRestart';
            app.UseFastRestartCheckBox.Layout.Row = 5;
            app.UseFastRestartCheckBox.Layout.Column = [4 5];

            % Create RunSimButton
            app.RunSimButton = uibutton(app.GridLayout2, 'push');
            app.RunSimButton.ButtonPushedFcn = createCallbackFcn(app, @RunSimButtonPushed, true);
            app.RunSimButton.FontSize = 14;
            app.RunSimButton.Layout.Row = 7;
            app.RunSimButton.Layout.Column = [2 4];
            app.RunSimButton.Text = '运行仿真';

            % Create Label_10
            app.Label_10 = uilabel(app.GridLayout2);
            app.Label_10.HorizontalAlignment = 'right';
            app.Label_10.FontSize = 14;
            app.Label_10.Layout.Row = 1;
            app.Label_10.Layout.Column = 1;
            app.Label_10.Text = '仿真基本设置';

            % Create Label_11
            app.Label_11 = uilabel(app.GridLayout2);
            app.Label_11.HorizontalAlignment = 'right';
            app.Label_11.Layout.Row = 2;
            app.Label_11.Layout.Column = 1;
            app.Label_11.Text = '仿真模式';

            % Create Label_12
            app.Label_12 = uilabel(app.GridLayout2);
            app.Label_12.HorizontalAlignment = 'right';
            app.Label_12.Layout.Row = 3;
            app.Label_12.Layout.Column = 1;
            app.Label_12.Text = '仿真停止时间';

            % Create Label_16
            app.Label_16 = uilabel(app.GridLayout2);
            app.Label_16.HorizontalAlignment = 'right';
            app.Label_16.Layout.Row = 4;
            app.Label_16.Layout.Column = 1;
            app.Label_16.Text = '仿真命令';

            % Create SimFcnDropDown
            app.SimFcnDropDown = uidropdown(app.GridLayout2);
            app.SimFcnDropDown.Items = {'串行仿真', '并行仿真'};
            app.SimFcnDropDown.Tooltip = {'控制使用sim或parsim函数进行仿真。对于较多的参数组合，使用并行仿真可以显著缩短耗时，但也会使用更多内存，并且启动速度较慢。当仿真数量较少、运行耗时很短或内存不足时，建议使用串行仿真。并行仿真需要有 Parallel Computing Toolbox 工具箱支持才可用，否则将退化为串行仿真。'};
            app.SimFcnDropDown.Layout.Row = 4;
            app.SimFcnDropDown.Layout.Column = 2;
            app.SimFcnDropDown.Value = '并行仿真';

            % Create PostProcessTab
            app.PostProcessTab = uitab(app.TabGroup);
            app.PostProcessTab.Tooltip = {'对仿真运行结果数据进行简单后处理'};
            app.PostProcessTab.Title = '快捷后处理';

            % Create GridLayout3
            app.GridLayout3 = uigridlayout(app.PostProcessTab);
            app.GridLayout3.ColumnWidth = {'1x', '2x', '2x', '2x', '2x', '1x'};
            app.GridLayout3.RowHeight = {45, '1x', '1x', '1x', '1x', '1x', 35, 38};

            % Create OutPortUITable
            app.OutPortUITable = uitable(app.GridLayout3);
            app.OutPortUITable.ColumnName = {'使用该数据'};
            app.OutPortUITable.RowName = {};
            app.OutPortUITable.ColumnEditable = true;
            app.OutPortUITable.DisplayDataChangedFcn = createCallbackFcn(app, @OutPortUITableDisplayDataChanged, true);
            app.OutPortUITable.Layout.Row = [2 6];
            app.OutPortUITable.Layout.Column = [1 3];

            % Create EasyPostProcessLabel
            app.EasyPostProcessLabel = uilabel(app.GridLayout3);
            app.EasyPostProcessLabel.FontSize = 14;
            app.EasyPostProcessLabel.Tooltip = {'将仿真结果中的部分数据以时间轴为横轴、值为纵轴绘图。便于比较不同参数组间仿真结果的差异。'};
            app.EasyPostProcessLabel.Layout.Row = 1;
            app.EasyPostProcessLabel.Layout.Column = [1 2];
            app.EasyPostProcessLabel.Text = '快捷后处理';

            % Create OpenParamSetBrowserButton
            app.OpenParamSetBrowserButton = uibutton(app.GridLayout3, 'push');
            app.OpenParamSetBrowserButton.ButtonPushedFcn = createCallbackFcn(app, @OpenParamSetBrowser, true);
            app.OpenParamSetBrowserButton.Layout.Row = 4;
            app.OpenParamSetBrowserButton.Layout.Column = [4 6];
            app.OpenParamSetBrowserButton.Text = '打开参数组浏览器';

            % Create Label_13
            app.Label_13 = uilabel(app.GridLayout3);
            app.Label_13.VerticalAlignment = 'bottom';
            app.Label_13.Layout.Row = 2;
            app.Label_13.Layout.Column = 4;
            app.Label_13.Text = '使用参数组：';

            % Create ParamSetEditField
            app.ParamSetEditField = uieditfield(app.GridLayout3, 'text');
            app.ParamSetEditField.ValueChangedFcn = createCallbackFcn(app, @ParamSetEditFieldValueChanged, true);
            app.ParamSetEditField.Tooltip = {'输入参数组序号，使用逗号或空格分隔，例如1,3,5-7。有效的参数组编号可以在参数组浏览器中查看。如不指定，则默认使用所有参数组。'};
            app.ParamSetEditField.Layout.Row = 3;
            app.ParamSetEditField.Layout.Column = [4 6];

            % Create RunEasyPostProcessButton
            app.RunEasyPostProcessButton = uibutton(app.GridLayout3, 'push');
            app.RunEasyPostProcessButton.ButtonPushedFcn = createCallbackFcn(app, @RunEasyPostProcessButtonPushed, true);
            app.RunEasyPostProcessButton.Layout.Row = 8;
            app.RunEasyPostProcessButton.Layout.Column = [3 4];
            app.RunEasyPostProcessButton.Text = '运行快捷后处理';

            % Create Label_15
            app.Label_15 = uilabel(app.GridLayout3);
            app.Label_15.VerticalAlignment = 'bottom';
            app.Label_15.Layout.Row = 5;
            app.Label_15.Layout.Column = [4 5];
            app.Label_15.Text = '后处理结果存储位置：';

            % Create PostResultEditField
            app.PostResultEditField = uieditfield(app.GridLayout3, 'text');
            app.PostResultEditField.Editable = 'off';
            app.PostResultEditField.Tooltip = {'存储快捷后处理结果的路径。如果不指定路径，则默认使用当前位置。'};
            app.PostResultEditField.Layout.Row = 6;
            app.PostResultEditField.Layout.Column = [4 5];

            % Create PostResultBrowseButton
            app.PostResultBrowseButton = uibutton(app.GridLayout3, 'push');
            app.PostResultBrowseButton.ButtonPushedFcn = createCallbackFcn(app, @PostResultBrowseButtonPushed, true);
            app.PostResultBrowseButton.Tooltip = {'选择后处理结果保存位置，默认为当前路径'};
            app.PostResultBrowseButton.Layout.Row = 6;
            app.PostResultBrowseButton.Layout.Column = 6;
            app.PostResultBrowseButton.Text = '浏览';

            % Create OthersTab
            app.OthersTab = uitab(app.TabGroup);
            app.OthersTab.Tooltip = {'其他功能'};
            app.OthersTab.Title = '更多';

            % Create GridLayout5
            app.GridLayout5 = uigridlayout(app.OthersTab);
            app.GridLayout5.ColumnWidth = {'1x', '1x', '1x'};
            app.GridLayout5.RowHeight = {'1x', '1x', '1x', '1x', '1x', '1x', '1x'};

            % Create ExportSimInButton
            app.ExportSimInButton = uibutton(app.GridLayout5, 'push');
            app.ExportSimInButton.ButtonPushedFcn = createCallbackFcn(app, @ExportSimInButtonPushed, true);
            app.ExportSimInButton.Layout.Row = 2;
            app.ExportSimInButton.Layout.Column = 1;
            app.ExportSimInButton.Text = '导出仿真对象至基础工作区';

            % Create ExportParamTableButton
            app.ExportParamTableButton = uibutton(app.GridLayout5, 'push');
            app.ExportParamTableButton.ButtonPushedFcn = createCallbackFcn(app, @ExportParamTableButtonPushed, true);
            app.ExportParamTableButton.Layout.Row = 2;
            app.ExportParamTableButton.Layout.Column = 2;
            app.ExportParamTableButton.Text = '导出参数组表格至基础工作区';

            % Create Label_17
            app.Label_17 = uilabel(app.GridLayout5);
            app.Label_17.FontSize = 14;
            app.Label_17.Layout.Row = 1;
            app.Label_17.Layout.Column = 1;
            app.Label_17.Text = '导出数据至工作区';

            % Create StatusBarLabel
            app.StatusBarLabel = uilabel(app.GridLayout6);
            app.StatusBarLabel.Layout.Row = 3;
            app.StatusBarLabel.Layout.Column = 1;
            app.StatusBarLabel.Text = '';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = SimConfigTool_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

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