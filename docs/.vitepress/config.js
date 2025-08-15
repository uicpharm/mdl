import { defineConfig } from 'vitepress'; // eslint-disable-line import/no-extraneous-dependencies
import { viteStaticCopy } from 'vite-plugin-static-copy';
import { spawnSync } from 'child_process';
import stripAnsi from 'strip-ansi';
import fs from 'fs';
import path from 'path';

/**
 * Generate an object of man pages with the key being the name of the script (i.e. `list`) and the
 * content being the output of `script -h`. The executor will appear as `vitepress.js` so we
 * explicitly substitute that with the conventional `mdl` script. Since the man pages use ANSI
 * codes for terminal formatting, we strip the ANSI codes as well.
 */
const scriptPath = path.resolve('./libexec');
const scriptExt = '.sh';
const manPages = fs.readdirSync(scriptPath)
   .filter((file) => file.endsWith(scriptExt))
   .reduce((acc, filename) => {
      const name = path.basename(filename, scriptExt);
      const content = spawnSync(`${scriptPath}/${filename}`, [ '-h' ])
         .stdout.toString()
         .replaceAll('vitepress.js', 'mdl');
      acc[name] = stripAnsi(content);
      return acc;
   }, {});

export default defineConfig({
   title: 'Moodle CLI: mdl',
   description: 'CLI to make Moodle in containers easy.',
   ignoreDeadLinks: 'localhostLinks',
   outDir: '../dist/docs',
   vite: {
      define: {
         __NODE_VERSION__: JSON.stringify(process.version),
         __SCRIPT_MAN_PAGES__: JSON.stringify(manPages),
      },
      ssr: {
         noExternal: [ '@uicpharm/vitepress-theme' ],
      },
      plugins: [
         viteStaticCopy({
            targets: [ { src: '../node_modules/@uicpharm/vitepress-theme/public/uic-logo.svg', dest: '.' } ],
         }),
      ],
   },
   themeConfig: {
      logo: '/uic-logo.svg',
      outline: 'deep',
      nav: [
         { text: 'Getting Started', link: 'getting-started' },
         {
            text: 'Reference',
            items: [
               { text: 'Box.com', link: 'box' },
               { text: 'Scripts', link: 'scripts' },
            ],
         },
         {
            text: 'Tips',
            items: [
               { text: 'Database Help', link: 'database' },
               { text: 'Proxy Help', link: 'proxy' },
            ],
         },
      ],
      socialLinks: [
         { icon: 'github', link: 'https://github.com/uicpharm/mdl#readme' },
      ],
   },
});
