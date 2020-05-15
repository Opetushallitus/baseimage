from github import Github
from git import Actor, Repo
import re
import requests
import os


def get_latest_release(repository_name):
    try:
        repository = g.get_repo(repository_name)
        latest_release_raw = repository.get_latest_release().tag_name
        latest_release = re.search('[0-9].*', latest_release_raw)[0]
        return latest_release
    except Exception as e:
        print(e)


def get_current_version(version_string):
    install_script_lines = open(os.path.join(
        repository_path, 'variants', 'fatjar-openjdk8', 'install.sh'), 'r').readlines()
    version_line_filter = f'{version_string}='
    version_line_index = [i for i, line in enumerate(
        install_script_lines) if line.startswith(version_line_filter)][0]
    version_line = install_script_lines[version_line_index].rstrip()
    version = re.search('(?<==").*[^"]', version_line).group(0)
    return version


def get_versions(packages):
    package_versions = packages
    for _, properties in package_versions.items():
        properties['current_version'] = get_current_version(
            properties['version_string'])
        properties['latest_version'] = get_latest_release(
            properties['repository_name'])
    return package_versions


def get_outdated_ext_packages(packages):
    return {package: properties for (package, properties) in packages.items() if properties['current_version'] != properties['latest_version']}


def send_message(repository_slug, base_image_branch, flow_token, outdated_ext_packages, apk_packages_updated):
    message_content = [
        f"Report for {repository_slug} ({base_image_branch})\n\n"]
    message_content.append("Alpine packages are outdated, new base image will be built\n\n") if apk_packages_updated else message_content.append(
        "Alpine packages are up to date\n\n")
    if outdated_ext_packages:
        message_content.append('Outdated external packages:\n')
        for package_name, properties in outdated_ext_packages.items():
            message_content.append(
                f'{package_name}\nInstalled: {properties["current_version"]}\nLatest: {properties["latest_version"]}\n\n')
    else:
        message_content.append('All external packages are up to date')

    flow_payload = {
        'flow_token': flow_token,
        'event': 'message',
        'content': ''.join(message_content)
    }

    print(''.join(message_content))
    r = requests.post('https://api.flowdock.com/messages', json=flow_payload)


if __name__ == "__main__":
    github_token = os.environ.get('GITHUB_TOKEN')
    #flow_token = os.environ.get('FLOW_TOKEN')
    repository_slug = os.environ.get('TRAVIS_REPO_SLUG')
    base_image_branch = os.environ.get('TRAVIS_BRANCH')
    repository_path = os.environ.get('TRAVIS_BUILD_DIR')
    repo = Repo(repository_path)
    g = Github(github_token)
    print(f'Working on repository:{repository_slug} branch: {base_image_branch} in path: {repository_path}')

    ext_packages = {
        'GNU C Library': {
            'version_string': 'GLIBC_VERSION',
            'repository_name': 'sgerrand/alpine-pkg-glibc'
        },
        'Prometheus node exporter': {
            'version_string': 'NODE_EXPORTER_VERSION',
            'repository_name': 'prometheus/node_exporter'
        },
        'Prometheus JMX exporter': {
            'version_string': 'JMX_EXPORTER_VERSION',
            'repository_name': 'prometheus/jmx_exporter'
        }
    }

    outdated_ext_packages = get_outdated_ext_packages(get_versions(ext_packages))
    apk_packages_updated = False
    if repo.is_dirty():
        author = Actor("oph-ci", "noreply@opintopolku.fi")
        repo.delete_remote('origin')
        repo.create_remote('origin', url=f'https://oph-ci:{github_token}@github.com/{repository_slug}.git')
        repo.index.add([os.path.join('variants')])
        repo.index.commit('Update Alpine packages', author=author)
        print(repo.remotes.origin.push(refspec=f'{base_image_branch}:{base_image_branch}')[0].summary)
        apk_packages_updated = True
    #send_message(repository_slug, base_image_branch, flow_token,
    #             outdated_ext_packages, apk_packages_updated)
