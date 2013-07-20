module.exports = function(grunt) {
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    watch: {
      scripts: {
        files: ['src/*'],
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
          'build/main.js': 'src/main.ls',
          'build/ui.js': 'src/ui.ls'
        }
      }
    },
    haml: {
      dist: {
        files: {
          'build/index.html': 'src/index.haml'
        }
      }
    }
  });

  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-livescript');
  grunt.loadNpmTasks('grunt-shell');
  grunt.loadNpmTasks('grunt-contrib-haml');

  grunt.registerTask('default', ['shell', 'livescript', 'haml']);
};
