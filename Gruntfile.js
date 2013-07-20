module.exports = function(grunt) {
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    watch: {
      scripts: {
        files: ['sass/main.sass', 'main.ls', 'ui.ls', 'index.haml'],
        tasks: ['default']
      }
    },
    shell: {
      compass: {
        command: 'compass compile'
      }
    },
    livescript: {
      src: {
        files: {
          'main.js': 'main.ls',
          'ui.js': 'ui.ls'
        }
      }
    }
  });

  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-livescript');
  grunt.loadNpmTasks('grunt-shell');

  grunt.registerTask('default', ['shell', 'livescript']);
};
