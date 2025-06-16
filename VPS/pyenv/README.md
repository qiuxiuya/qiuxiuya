### 安装Pyenv

```
curl -fsSL https://pyenv.run | bash
```

### 刷新环境

```
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(pyenv init - bash)"' >> ~/.bashrc
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.profile
echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.profile
echo 'eval "$(pyenv init - bash)"' >> ~/.profile
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bash_profile
echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bash_profile
echo 'eval "$(pyenv init - bash)"' >> ~/.bash_profile
source ~/.bashrc
```

### 安装依赖

```
apt install -y make build-essential libssl-dev zlib1g-dev \
  libbz2-dev libreadline-dev libsqlite3-dev  llvm \
  libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
```

### 列出Python正式版

```
pyenv install --list | grep -E '^\s*[0-9]+\.[0-9]+\.[0-9]+$'
```

### 安装所需要的版本(比如3.12.0)

```
pyenv install 3.12.0
```

此过程依性能决定，需要编译较长的时间.

### 应用你安装的Python

```
pyenv global 3.12.0
```

### 替换下系统的Python

```
rm /usr/bin/python3
ln -s $(pyenv which python3) /usr/bin/python3
```

### 更新pip

```
pip install --upgrade pip
```

### 卸载编译前安装的依赖

```
apt autoremove -y make build-essential libssl-dev zlib1g-dev \
  libbz2-dev libreadline-dev libsqlite3-dev  llvm \
  libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
```
