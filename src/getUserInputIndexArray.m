function indexArray = getUserInputIndexArray(userInput)
% 处理用户输入的字符串，返回实际有效的索引序号数组
% 接收用户输入的形如 "1,5-8,11" 这样的文本，返回对应的索引数组 [1,5,6,7,8,11]

tempStr = userInput;

while contains(tempStr, "  ")
    tempStr = strrep(tempStr, "  ", " "); % 连续多个空格合并成一个
end
tempStr = strrep(tempStr, "，", ","); % 将中文逗号替换为英文半角逗号
tempStr = strrep(tempStr, ", ", ","); % 去逗号后的空格
tempStr = strrep(tempStr, "~", "-"); % 处理鄂化符
tempStr = strrep(tempStr, "—", "-"); % 处理中文输入法半破折号

% 以空格、逗号分别作为分隔符分割两次字符串，能够处理混合情况
tempStrArray1 = split(tempStr, " ");
tempStrArray2 = strings;
for index = 1:length(tempStrArray1)
    tempStrArray2 = [tempStrArray2, split(tempStrArray1(index), ",")'];
end

% 将形如"2-5"的输入解析为"2 3 4 5"
for index = 1:length(tempStrArray2)
    if contains(tempStrArray2(index), '-')
        tempStrArray3 = split(tempStrArray2(index), "-");
        tempStrArray2(index) = [];
        tempStrArray2 = [tempStrArray2, string(...
            str2double(tempStrArray3(1)):str2double(tempStrArray3(end)))];
    end
end

tempStrArray2 = unique(tempStrArray2);
indexArray = str2double(tempStrArray2(2:end));
end