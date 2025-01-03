'use strict';
'require form';
'require view';
'require fs';

return view.extend({
    load: function () {
        return fs.stat('/www/tinyfilemanager').then(function (stat) {
            if (stat.type === 'directory') {
                return '/tinyfilemanager/index.php?p=etc%2Fmihomo';
            } else {
                throw new Error('Directory TinyFileManager not found');
            }
        }).catch(function () {
            return fs.stat('/www/tinyfm').then(function (stat) {
                if (stat.type === 'directory') {
                    return '/tinyfm/tinyfm.php?p=etc%2Fmihomo';
                } else {
                    throw new Error('Directory TinyFileManager not found');
                }
            }).catch(function () {
                return fs.stat('/www/tinyfm').then(function (stat) {
                    if (stat.type === 'directory') {
                        return '/tinyfm/index.php?p=etc%2Fmihomo';
                    } else {
                        throw new Error('Directory TinyFileManager not found');
                    }
                }).catch(function () {
                    return null; // Indicate that no valid path is found
                });
            });
        });
    },
    render: function (iframePath) {
        const host = window.location.hostname;

        if (iframePath) {
            const iframeUrl = `http://${host}${iframePath}`;
            return E('div', { class: 'cbi-section' }, [
                E('iframe', {
                    src: iframeUrl,
                    style: 'width: 100%; height: 80vh; border: none;',
                }, _('Your browser does not support iframes.'))
            ]);
        } else {
            // Render error message or alternative content
            const m = new form.Map('mihomo', _('Advanced Editor | ERROR'),
                `${_('Transparent Proxy with Mihomo on OpenWrt.')} <a href="https://github.com/morytyann/OpenWrt-mihomo/wiki" target="_blank">${_('How To Use')}</a>`
            );

            const s = m.section(form.NamedSection, 'error', 'error', _('Error'));
            s.anonymous = true;
            s.render = function () {
                return E('div', { class: 'error-container', style: 'padding: 20px; background: #fff; border: 1px solid #ccc; border-radius: 8px;' }, [
                    E('h4', { style: 'color: #d9534f;' }, _('Advanced Editor cannot be run because <strong>TinyFileManager</strong> is not found.')),
                    E('p', { style: 'margin-bottom: 15px;' }, _('Please install it first to use the Advanced Editor.')),
                    E('ul', { style: 'padding-left: 20px; list-style-type: disc;' }, [
                        E('li', {}, [
                            E('strong', {}, _('Install Directly in OpenWrt via the Software Menu in LuCI (<strong>If Supported</strong>):')),
                            E('ul', { style: 'padding-left: 20px; list-style-type: circle;' }, [
                                E('li', {}, _('Search for the package: <strong>luci-app-tinyfilemanager</strong>'))
                            ])
                        ]),
                        E('li', {}, [
                            E('strong', {}, _('Install Manually:')),
                            E('ul', { style: 'padding-left: 20px; list-style-type: circle;' }, [
                                E('li', {}, _('Download the TinyFileManager package for your OpenWrt architecture.')),
                                E('li', {}, E('a', {
                                    href: 'https://github.com/muink/luci-app-tinyfilemanager',
                                    target: '_blank',
                                    rel: 'noopener noreferrer',
                                    style: 'color: #337ab7; text-decoration: underline;'
                                }, _('Click here to download the TinyFileManager package.'))),
                                E('li', {}, _('Go to <strong>System</strong> -> <strong>Software</strong> -> Click <strong>UPDATE LIST...</strong> -> <strong>UPLOAD PACKAGE...</strong>')),
                                E('li', {}, _('Choose the downloaded TinyFileManager package file.')),
                                E('li', {}, _('Click <strong>UPLOAD</strong> and then <strong>INSTALL</strong>.'))
                            ])
                        ])
                    ])
                ]);
            };
            return m.render();
        }
    },
});